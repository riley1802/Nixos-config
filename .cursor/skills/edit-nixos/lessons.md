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

### Dashboard tiles with 127.0.0.1 hrefs are dead for remote clients (2026-07-18)
- **Context:** Homepage is served via Tailscale Serve; AI tiles (llama/whisper/piper) linked to `http://127.0.0.1:808x`.
- **Error:** Clicking whisper.cpp / Piper tiles from another tailnet device did nothing ("doesn't work at all"), though services were healthy.
- **Cause:** `href` is followed by the *client* browser — 127.0.0.1 resolves to the client, not the server. `siteMonitor` (server-side) can stay localhost.
- **Fix:** Added Serve mappings `:8080/:8081/:8082` in `tailscale-serve.nix` and pointed tile `href`s at `https://nixos.taile9f484.ts.net:<port>`.
- **Avoid:** Never use localhost URLs in Homepage `href`s; localhost is fine only for `siteMonitor`/widget URLs.

### llama.cpp router OOMs loading a second model (2026-07-18)
- **Context:** llama-server router mode (`modelsPreset`) with default `max_instances=4` on 6 GiB + 6 GiB GPUs.
- **Error:** Web UI model switch → `cudaMalloc failed: out of memory`, `model failed to load` 500.
- **Cause:** Router keeps the current model resident and tries to load the next one alongside it; VRAM only fits one.
- **Fix:** `--models-max 1` in `extraFlags` — router evicts the loaded model before loading the requested one.
- **Avoid:** Leaving router `--models-max` at default on VRAM-constrained hosts with multiple presets.

### piper CLI writes output.wav to cwd, not stdout (2026-07-18)
- **Context:** Piper HTTP wrapper captured `subprocess.run(...).stdout` for the WAV response.
- **Error:** `/synthesize` returned HTTP 200 with 0-byte body; stray `output.wav` appeared in the voices dir.
- **Cause:** This piper build defaults `-f/--output-file` to a file in cwd despite help text claiming stdout default.
- **Fix:** Pass `--output-file -` explicitly to force WAV to stdout.
- **Avoid:** Trusting piper's default output target; always pass `-f -` when capturing stdout.

### Tauri Homeport webview caches Homepage CSS across rebuilds (2026-07-18)
- **Context:** Updated `homepage-dashboard` `customCSS` / layout; browser at `:8083` showed the new chrome, but the Homeport tray window still looked unchanged.
- **Error:** Stale dashboard UI in `homeport-tray` after `nixos-rebuild switch` + `homepage-dashboard` restart.
- **Cause:** The tray WebView keeps a live document (and WebKitGTK caches `/api/config/custom.css` by ETag). Hiding/showing the window does not reload; tray **Reload** used `location.reload()`, which can reuse cached CSS.
- **Fix:** Restart `homeport-tray` after dashboard chrome changes only when that user unit is installed; otherwise reload the browser with a cache-busting query. The former tray Reload used `location.replace(origin + '/?' + Date.now())`; `customJS` rewrites the `custom.css` link with a cache-buster query.
- **Avoid:** Assuming a Homepage rebuild is enough for an already-open client, or assuming the optional `homeport-tray.service` unit exists — check the unit first, then reload the active client when changing `customCSS` / services layout.

### Homepage bookmark groups do not nest under service groups (2026-07-18)
- **Context:** Reshaping Homeport (`homepage-dashboard.nix`) to a whiteboard grid with Apps + Bookmarks side-by-side in a nested Workspace row.
- **Error:** Nested `bookmarks.yaml` under `Workspace → Bookmarks` either failed to render or only exposed the first link; `/api/bookmarks` returned a malformed object instead of a group of links.
- **Cause:** Homepage supports nested *service* groups, but bookmark groups are effectively top-level only — deep nesting is not parsed like services.
- **Fix:** Represent the Bookmarks cell as a nested *service* group (href tiles) under Workspace so layout columns work; leave `bookmarks = [ ]`.
- **Avoid:** Nesting `bookmarks.yaml` groups under service parents when you need a multi-column Homepage layout — use service tiles or keep bookmarks top-level.

### WebKitGTK + NVIDIA + Wayland crashes (and silent input desync) on hide()/show() (2026-07-18)
- **Context:** `apps/homeport-tray` (Tauri v2 tray app; close-to-tray hides the window, tray click / single-instance re-launch shows it again) on this machine's dual-NVIDIA GNOME/Wayland session.
- **Error:** `Gdk-Message: Error 71 (Protocol error) dispatching to Wayland display.` — the whole process died every time a hidden window was shown again (systemd unit crash-looped). Even when the process survived, a subtler symptom showed up later: the window stayed responsive (draggable, focusable, tray icon worked) but clicks inside the dashboard page did nothing at all — the accelerated surface was silently desynced rather than crashing outright.
- **Cause:** Known upstream WebKitGTK DMABUF renderer / NVIDIA driver desync on Wayland (tauri-apps/tauri#10702, #9394) — the accelerated compositing surface gets into a bad state across a `hide()` → `show()` cycle on a *reused* window/webview. Not related to threading (adding `run_on_main_thread` for the GTK calls did not fix it), and the `WEBKIT_DISABLE_DMABUF_RENDERER=1` / `__NV_DISABLE_EXPLICIT_SYNC=1` env vars alone reduced crashes but did not eliminate the unresponsive-clicks case.
- **Fix:** Two layers: (1) keep the env vars (`std::env::set_var` at the very top of `main()`, before `tauri::Builder::default()`; see https://v2.tauri.app/develop/debug/linux-graphics/); (2) never `hide()`/re`show()` the same window — `hide_dashboard` calls `window.destroy()` instead, and `show_dashboard` rebuilds a fresh window with `WebviewWindowBuilder` when none exists. This removes the hide()/show() cycle entirely rather than just mitigating its symptoms. Keeping the app alive with zero windows requires handling `RunEvent::ExitRequested { api, code }` and calling `api.prevent_exit()` when `code.is_none()` (i.e. the exit wasn't requested via `app.exit(n)`), per the official Tauri example (`examples/api/src-tauri/src/lib.rs`) and tauri-apps/tauri#13511.
- **Avoid:** Assuming a Tauri window that gets hidden and re-shown (tray apps, "start minimized") is safe by default on NVIDIA + Wayland, and assuming a lack of a crash means the workaround succeeded — a desynced surface can look fully responsive (window chrome, focus, drag) while page clicks are silently swallowed. Prefer destroy+rebuild over hide()/show() for any Tauri window that gets toggled repeatedly on this machine.

### libayatana-appindicator dlopen fails at runtime for Tauri tray apps (2026-07-18)
- **Context:** Packaging `apps/homeport-tray` (Tauri v2, `tray-icon` feature) with `rustPlatform.buildRustPackage` + `wrapGAppsHook3`; `libayatana-appindicator` in `buildInputs`.
- **Error:** `thread 'main' panicked … Failed to load ayatana-appindicator3 or appindicator3 dynamic library … cannot open shared object file`, crash-looped under `systemd --user`.
- **Cause:** `libappindicator-sys` `dlopen()`s `libayatana-appindicator3.so.1` at runtime instead of linking it; `wrapGAppsHook3`'s generated wrapper doesn't add plain `buildInputs` libs to `LD_LIBRARY_PATH` for dlopen use cases.
- **Fix:** In `preFixup`, append to the hook's own wrapper args: `gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libayatana-appindicator ]}")`.
- **Avoid:** Assuming `buildInputs` alone is enough for Rust crates that `dlopen()` system libraries (tray/appindicator, some codecs) — check for panics naming a `.so` even after a clean build.

### Tauri app needs Cargo.toml at `src` root for buildRustPackage (2026-07-18)
- **Context:** `apps/homeport-tray/default.nix` with `src = ./src-tauri` and `frontendDist: "../dist"` (dist as a sibling of `src-tauri`).
- **Error:** `error: could not find Cargo.toml in /build/source or any parent directory` (after trying `cargoRoot = "src-tauri"` with `src = ./.`), then `frontendDist … doesn't exist` (when `src = ./src-tauri` only).
- **Cause:** `buildRustPackage`'s `cargoRoot` didn't relocate the build's working directory the way expected; and excluding the frontend dir from `src` broke Tauri's `frontendDist` resolution (relative to `tauri.conf.json`, i.e. inside `src-tauri/`).
- **Fix:** Keep `Cargo.toml` at the derivation's `src` root (`src = ./src-tauri`) and move the placeholder frontend to `src-tauri/dist/`, with `frontendDist: "dist"` (no `../`).
- **Avoid:** Splitting a Tauri project's frontend dir outside the `src-tauri/` Cargo root when packaging with plain `buildRustPackage` (no `cargoRoot` juggling needed if everything Tauri needs stays under one root).

### Tauri tray icon PNGs must be RGBA (2026-07-18)
- **Context:** `tauri::include_image!`/`generate_context!` embedding `icons/tray-normal.png` generated via `imagemagick convert -size 128x128 xc:'#38bdf8'`.
- **Error:** `proc macro panicked … icon … is not RGBA`.
- **Cause:** Plain `xc:` flat-color PNGs from ImageMagick default to RGB (no alpha channel); Tauri's tray/window icon loader requires RGBA.
- **Fix:** Regenerate with an explicit alpha channel: `convert -size 128x128 xc:'#38bdf8' -alpha set PNG32:icon.png`.
- **Avoid:** Assuming any PNG works for Tauri icons — verify RGBA (`identify -format %A icon.png` or just always force `-alpha set`).

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

### PRIME offload black-screens when the laptop MUX is in Discrete mode (2026-07-18)

- **Context:** New `legion` host (Legion 5 Pro 16ARH7H, AMD 680M + RTX 3070 Ti) with Cinnamon/LightDM (X11) and `hardware.nvidia.prime.offload` (generation 6).
- **Error:** Boot flashed black → boot text → stayed black. LightDM/X started fine per journal; Xorg log: `AMDGPU(0): Unable to find connected outputs - setting 1024x768 initial framebuffer`; kernel: `amdgpu: Cannot find any crtc or sizes`.
- **Cause:** BIOS "GPU Working Mode" was Discrete/dGPU — the MUX wires the internal panel (eDP-1) to the NVIDIA card, so the iGPU that offload mode makes primary has zero connected outputs; the greeter rendered into an invisible dummy framebuffer. The previous GDM/Wayland generation masked this because mutter drove the NVIDIA card directly.
- **Fix:** Set BIOS GPU Working Mode to Hybrid so eDP-1 attaches to the iGPU and the offload config works as designed. (Alternative: NVIDIA-primary config with offload + finegrained power management removed.)
- **Avoid:** Deploying PRIME offload on a MUXed laptop without confirming which GPU owns eDP-1 first — check `/sys/class/drm/card*-eDP-*/status` and which card it hangs off before choosing offload vs sync/primary.
