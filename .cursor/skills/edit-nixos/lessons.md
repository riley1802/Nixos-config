# NixOS config lessons

Append entries when a build, rebuild, or runtime error is resolved. Format:

```
### Short title (YYYY-MM-DD)
- **Context:** …
- **Error:** …
- **Cause:** …
- **Fix:** …
- **Avoid:** …
```

---

### Uptime Kuma 2.x requires `conditions` on monitor create (2026-07-18)
- **Context:** `uptime-kuma-sync` creating monitors via `python3Packages.uptime-kuma-api` 1.2.1 against Uptime Kuma 2.4.0.
- **Error:** `SQLITE_CONSTRAINT: NOT NULL constraint failed: monitor.conditions`.
- **Cause:** Kuma 2.x added a NOT NULL `conditions` column (default `[]`); the Socket.IO payload from uptime-kuma-api omits it, so SQLite inserts NULL.
- **Fix:** Before `_call('add'|'editMonitor')`, set `data["conditions"] = []` when missing/None.
- **Avoid:** Assuming uptime-kuma-api field coverage matches current Kuma schema without testing create.

### agenix secret edit needs activation refresh (2026-07-18)
- **Context:** User ran `agenix -e uptime-kuma-sync.env.age` then only `systemctl restart uptime-kuma-sync`.
- **Error:** Sync still saw old `REPLACE_ME` password.
- **Cause:** agenix decrypts into `/run/agenix` at NixOS activation; restarting the unit reuses the previous decrypted file.
- **Fix:** After editing a `*.age` used as `EnvironmentFile`, run `pkexec nixos-rebuild switch` (or re-decrypt into the current `/run/agenix.d/<n>/` path) before restarting the unit.
- **Avoid:** Expecting `systemctl restart` alone to pick up a newly edited `.age` file.

### agenix EDITOR must write `$1` (2026-07-18)
- **Context:** Creating `secrets/uptime-kuma-sync.env.age` non-interactively with `EDITOR="cp /tmp/file"`.
- **Error:** Decrypted `/run/agenix/uptime-kuma-sync` was 0 bytes; sync failed with `missing required env var`.
- **Cause:** agenix invokes `$EDITOR <tempfile>`; `cp src` ignores the destination path argument, so the temp file stays empty and that empty content is encrypted.
- **Fix:** Use an editor script that writes to `"$1"`, or encrypt with `age -e -r … -o secret.age plaintext`.
- **Avoid:** `EDITOR="cp …"` without copying *into* the path agenix passes as `$1`.

### Flakes ignore untracked files (2026-06-30)
- **Context:** Adding new modules before `nixos-rebuild`.
- **Error:** Rebuild used old config; new files missing from evaluation.
- **Cause:** Nix flakes only include tracked git files (unless `--impure` with dirty tree nuances).
- **Fix:** `git add` new modules before rebuild; commit when ready.
- **Avoid:** Leaving new `.nix` files untracked when testing on another host.

### Bare `nix fmt` hangs (2026-07-04)
- **Context:** Pre-rebuild validation.
- **Error:** `nix fmt && nix flake check && nix build …` never progressed; `nixpkgs-fmt` slept 12+ minutes with no output.
- **Cause:** `nix fmt` with **no path arguments** launches `nixpkgs-fmt` without a file list and waits indefinitely.
- **Fix:** Pass paths: `nix fmt .` or `nix fmt path/to/changed.nix`; CI-style check: `nix fmt -- --check .`.
- **Avoid:** Chaining bare `nix fmt` in validation scripts or agent shells.

### `nix fmt` / `''` shell escapes in Nix strings (2026-07-18)
- **Context:** Onescript in `n8n.nix` used `sed "s/'/''/g"` inside a Nix `'' ... ''` string to SQL-escape quotes.
- **Error:** `syntax error, unexpected invalid token` after `nix fmt .`; script body split across lines.
- **Cause:** In Nix indented strings, `''` ends the string / escapes quotes; `nixpkgs-fmt` rewrote the sed pattern and broke evaluation.
- **Fix:** Use a base64 password and `psql -c "ALTER USER n8n PASSWORD '$pass'"` (no nested `''` / no sed).
- **Avoid:** Putting shell `''` / SQL quote-doubling patterns inside Nix `''` strings; re-check `nix flake check` after formatting files that embed shell.

### ntfy rejects path in `base-url` (2026-07-18)
- **Context:** ntfy behind nginx at `/ntfy/` with `base-url = "http://…/ntfy"`.
- **Error:** `base-url must not have a path (/ntfy), as hosting ntfy on a sub-path is not supported` (ntfy 2.23).
- **Cause:** Upstream dropped/forbids subpath hosting for `base-url`.
- **Fix:** Run ntfy on its own Tailscale port (`0.0.0.0:8090`, firewall `8090` on `tailscale0`); remove nginx `/ntfy/` location.
- **Avoid:** Assuming ntfy subpath proxy configs from older docs still work.

### oci-containers `--restart` conflicts with `--rm` (2026-07-18)
- **Context:** Portainer `extraOptions = [ "--restart=unless-stopped" ]`.
- **Error:** `docker: conflicting options: cannot specify both --restart and --rm`.
- **Cause:** NixOS `virtualisation.oci-containers` already passes `--rm`; systemd unit handles restart policy.
- **Fix:** Omit Docker `--restart` in `extraOptions`; rely on the generated systemd service.
- **Avoid:** Copying bare `docker run --restart=…` flags into `oci-containers.extraOptions`.

### Portainer subpath proxy must strip prefix (2026-07-18)
- **Context:** Portainer used `--base-url=/portainer` behind nginx at `/portainer/`.
- **Error:** `/portainer/` returned HTTP 404 while Portainer's root returned 200.
- **Cause:** nginx forwarded `/portainer/` to the backend; Portainer requires the reverse proxy to strip the configured base URL.
- **Fix:** Use `proxyPass = "https://127.0.0.1:9443/";` inside `locations."/portainer/"`.
- **Avoid:** Including `/portainer/` in both the nginx upstream URL and Portainer's `--base-url`.

### psql `:'var'` not expanded in `-c` (2026-07-18)

- **Context:** `n8n-postgres-password` oneshot set the DB password via `psql --set=pass=... -c "ALTER USER n8n PASSWORD :'pass'"`.
- **Error:** `ERROR: syntax error at or near ":"` — Postgres received literal `:'pass'`.
- **Cause:** psql does not perform `:'variable'` interpolation inside `-c` command strings.
- **Fix:** Pass the password directly in `-c` when the secret charset cannot include `'`, or use a SQL file / here-doc where interpolation works.
- **Avoid:** Relying on `:'var'` with `psql -c`.

### n8n `N8N_PATH` subpath is broken (2026-07-18)
- **Context:** n8n behind nginx at `/n8n/` with `N8N_PATH=/n8n/`.
- **Error:** Homepage link to `/n8n/` showed a broken UI / 404; `/n8n/assets/…` and `/n8n/rest/…` returned HTML (`text/html`) instead of JS/JSON.
- **Cause:** n8n 2.25.7 prefixes the editor HTML with `/n8n/` but still serves assets and REST at `/assets/` and `/rest/`.
- **Fix:** Drop `N8N_PATH`; bind n8n to `127.0.0.1:5678` and expose HTTPS via Tailscale Serve on `:5678`.
- **Avoid:** Hosting n8n under a path prefix; prefer Serve/dedicated HTTPS port or subdomain.

### Tailscale Serve `set-config` cannot do HTTPS (2026-07-18)
- **Context:** Wanted declarative HTTPS for Homepage/n8n/Portainer via `services.tailscale.serve`.
- **Error:** `set-config` registers HTTP (not HTTPS) endpoints; CLI `--https` works.
- **Cause:** Upstream config format / nixpkgs module cannot express TLS termination (`nixpkgs#530174`, `tailscale#18381`).
- **Fix:** Oneshoot `tailscale serve --bg --https=…` in `modules/services/tailscale-serve.nix`; do not bind backends to `0.0.0.0` on the same port Serve uses.
- **Avoid:** Assuming `services.tailscale.serve.services.*.endpoints."tcp:443"` terminates TLS.
