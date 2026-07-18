#!/usr/bin/env python3
"""Idempotently sync Nix-declared monitors into Uptime Kuma via Socket.IO API."""

from __future__ import annotations

import json
import os
import sys
import time

from uptime_kuma_api import MonitorType, NotificationType, UptimeKumaApi, UptimeKumaException

KUMA_URL = os.environ.get("KUMA_URL", "http://127.0.0.1:3001")
NTFY_SERVER = os.environ.get("NTFY_SERVER", "http://127.0.0.1:8090")
TAG_COLOR = "#64748b"


def require_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"missing required env var: {name}")
    return value


def wait_for_kuma(url: str, attempts: int = 30, delay: float = 2.0) -> None:
    import urllib.error
    import urllib.request

    for i in range(attempts):
        try:
            with urllib.request.urlopen(url, timeout=3) as resp:
                if resp.status < 500:
                    return
        except (urllib.error.URLError, TimeoutError, OSError):
            pass
        time.sleep(delay)
    raise SystemExit(f"Uptime Kuma not reachable at {url} after {attempts} attempts")


def ensure_tag(api: UptimeKumaApi, name: str) -> int:
    for tag in api.get_tags():
        if tag.get("name") == name:
            return int(tag["id"])
    created = api.add_tag(name=name, color=TAG_COLOR)
    return int(created["id"])


def ensure_notification(api: UptimeKumaApi, name: str, topic: str) -> int:
    for n in api.get_notifications():
        if n.get("name") == name:
            api.edit_notification(
                int(n["id"]),
                name=name,
                type=NotificationType.NTFY,
                isDefault=False,
                applyExisting=False,
                ntfyserverurl=NTFY_SERVER,
                ntfytopic=topic,
                ntfyPriority=3,
                ntfyAuthenticationMethod="",
            )
            return int(n["id"])
    result = api.add_notification(
        name=name,
        type=NotificationType.NTFY,
        isDefault=False,
        applyExisting=False,
        ntfyserverurl=NTFY_SERVER,
        ntfytopic=topic,
        ntfyPriority=3,
        ntfyAuthenticationMethod="",
    )
    return int(result["id"])


def ensure_group(api: UptimeKumaApi, name: str, by_name: dict) -> int:
    existing = by_name.get(name)
    if existing is not None:
        mon_type = existing.get("type")
        type_val = mon_type.value if hasattr(mon_type, "value") else mon_type
        if type_val == MonitorType.GROUP.value or type_val == "group":
            return int(existing["id"])
        raise SystemExit(f"monitor name conflict (expected group): {name}")
    result = api.add_monitor(type=MonitorType.GROUP, name=name)
    mid = int(result["monitorID"])
    # Refresh local index
    for m in api.get_monitors():
        if int(m["id"]) == mid:
            by_name[name] = m
            break
    return mid


def monitor_has_tag(monitor: dict, tag_name: str) -> bool:
    for tag in monitor.get("tags") or []:
        if tag.get("name") == tag_name:
            return True
    return False


def desired_kwargs(spec: dict, group_id: int | None, notification_id: int) -> dict:
    mtype = MonitorType(spec["type"])
    kwargs: dict = {
        "type": mtype,
        "name": spec["name"],
        "interval": int(spec.get("interval", 60)),
        "retryInterval": int(spec.get("retryInterval", 60)),
        "maxretries": int(spec.get("maxretries", 3)),
        "notificationIDList": [notification_id],
        "parent": group_id,
    }
    if mtype == MonitorType.HTTP:
        kwargs["url"] = spec["url"]
        kwargs["ignoreTls"] = bool(spec.get("ignoreTls", False))
        kwargs["maxredirects"] = int(spec.get("maxredirects", 10))
        kwargs["accepted_statuscodes"] = spec.get("accepted_statuscodes", ["200-299"])
    elif mtype == MonitorType.PORT:
        kwargs["hostname"] = spec["hostname"]
        kwargs["port"] = int(spec["port"])
    else:
        raise SystemExit(f"unsupported monitor type in desired state: {spec['type']}")
    return kwargs


def needs_update(existing: dict, kwargs: dict) -> bool:
    type_val = existing.get("type")
    type_val = type_val.value if hasattr(type_val, "value") else type_val
    want_type = kwargs["type"].value if hasattr(kwargs["type"], "value") else kwargs["type"]
    if type_val != want_type:
        return True
    if int(existing.get("interval") or 0) != kwargs["interval"]:
        return True
    if int(existing.get("maxretries") or 0) != kwargs["maxretries"]:
        return True
    if existing.get("parent") != kwargs.get("parent"):
        return True
    notif = existing.get("notificationIDList") or []
    if sorted(int(x) for x in notif) != sorted(kwargs["notificationIDList"]):
        return True
    if want_type == "http":
        if existing.get("url") != kwargs.get("url"):
            return True
        if bool(existing.get("ignoreTls")) != bool(kwargs.get("ignoreTls")):
            return True
    if want_type == "port":
        if existing.get("hostname") != kwargs.get("hostname"):
            return True
        if int(existing.get("port") or 0) != int(kwargs.get("port") or 0):
            return True
    return False


def ensure_monitor_tag(api: UptimeKumaApi, tag_id: int, monitor_id: int, tag_name: str, monitor: dict) -> None:
    if monitor_has_tag(monitor, tag_name):
        return
    api.add_monitor_tag(tag_id=tag_id, monitor_id=monitor_id, value="")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <monitors.json>")

    username = require_env("KUMA_USERNAME")
    password = require_env("KUMA_PASSWORD")
    topic = require_env("NTFY_TOPIC")

    if password == "REPLACE_ME":
        print(
            "uptime-kuma-sync: KUMA_PASSWORD is still REPLACE_ME — "
            "run: agenix -e secrets/uptime-kuma-sync.env.age "
            "then: systemctl restart uptime-kuma-sync.service",
            file=sys.stderr,
        )
        return

    with open(sys.argv[1], encoding="utf-8") as f:
        desired = json.load(f)

    tag_name = desired["tag"]
    notification_name = desired["notificationName"]
    groups = desired.get("groups") or []
    monitors = desired.get("monitors") or []

    wait_for_kuma(KUMA_URL)

    with UptimeKumaApi(KUMA_URL, timeout=30) as api:
        try:
            api.login(username, password)
        except UptimeKumaException as e:
            raise SystemExit(
                "Uptime Kuma login failed — set KUMA_USERNAME/KUMA_PASSWORD in "
                "secrets/uptime-kuma-sync.env.age (admin must already exist in UI)"
            ) from e

        tag_id = ensure_tag(api, tag_name)
        notification_id = ensure_notification(api, notification_name, topic)

        by_name = {m["name"]: m for m in api.get_monitors()}

        group_ids: dict[str, int] = {}
        for gname in groups:
            gid = ensure_group(api, gname, by_name)
            group_ids[gname] = gid
            # Tag groups too so stale cleanup can remove them if dropped from Nix
            mon = by_name.get(gname) or next(
                (m for m in api.get_monitors() if m["name"] == gname), None
            )
            if mon is not None:
                ensure_monitor_tag(api, tag_id, int(mon["id"]), tag_name, mon)
                by_name[gname] = api.get_monitor(int(mon["id"]))

        desired_names = set(groups)
        for spec in monitors:
            name = spec["name"]
            desired_names.add(name)
            group_name = spec.get("group")
            group_id = group_ids.get(group_name) if group_name else None
            kwargs = desired_kwargs(spec, group_id, notification_id)

            existing = by_name.get(name)
            if existing is None:
                result = api.add_monitor(**kwargs)
                mid = int(result["monitorID"])
                print(f"created monitor: {name} ({mid})")
            else:
                mid = int(existing["id"])
                if needs_update(existing, kwargs):
                    api.edit_monitor(mid, **kwargs)
                    print(f"updated monitor: {name} ({mid})")
                else:
                    print(f"unchanged monitor: {name} ({mid})")

            refreshed = api.get_monitor(mid)
            ensure_monitor_tag(api, tag_id, mid, tag_name, refreshed)
            by_name[name] = refreshed

        # Delete stale nix-managed monitors first, then groups (children before parents)
        stale = [
            m
            for m in api.get_monitors()
            if m.get("name") not in desired_names and monitor_has_tag(m, tag_name)
        ]

        def is_group(m: dict) -> bool:
            t = m.get("type")
            t = t.value if hasattr(t, "value") else t
            return t == "group"

        for mon in [m for m in stale if not is_group(m)] + [m for m in stale if is_group(m)]:
            mid = int(mon["id"])
            name = mon.get("name")
            api.delete_monitor(mid)
            print(f"deleted stale nix-managed monitor: {name} ({mid})")

    print("uptime-kuma sync complete")


if __name__ == "__main__":
    main()
