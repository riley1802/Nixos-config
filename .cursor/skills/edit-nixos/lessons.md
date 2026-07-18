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

### psql `:'var'` not expanded in `-c` (2026-07-18)

- **Context:** `n8n-postgres-password` oneshot set the DB password via `psql --set=pass=... -c "ALTER USER n8n PASSWORD :'pass'"`.
- **Error:** `ERROR: syntax error at or near ":"` — Postgres received literal `:'pass'`.
- **Cause:** psql does not perform `:'variable'` interpolation inside `-c` command strings.
- **Fix:** Pass the password directly in `-c` when the secret charset cannot include `'`, or use a SQL file / here-doc where interpolation works.
- **Avoid:** Relying on `:'var'` with `psql -c`.
