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
- **Fix:** Drop `N8N_PATH` and the nginx `/n8n/` location; expose n8n on `tailscale0:5678` (same pattern as ntfy / Uptime Kuma).
- **Avoid:** Hosting n8n under a path prefix; prefer a dedicated port or subdomain.
