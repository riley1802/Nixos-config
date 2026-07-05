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

### Hermes WhatsApp before bridge install (2026-07-04)
- **Context:** Declarative Hermes with `WHATSAPP_ENABLED=true` on first deploy.
- **Error:** `hermes-agent.service` exit status 78 (CONFIG); `WhatsApp bridge script missing at .../scripts/whatsapp-bridge/bridge.js`.
- **Cause:** Nix-packaged Hermes does not ship the WhatsApp bridge in the store path; `hermes whatsapp` installs it into `$HERMES_HOME` first.
- **Fix:** Set `WHATSAPP_ENABLED=false` until after `hermes whatsapp` pairing; add `nodejs` to `extraPackages`; then enable and rebuild.
- **Avoid:** Enabling WhatsApp in Nix env before running the one-time `hermes whatsapp` setup.

### Hermes config merge keeps removed keys (2026-07-04)
- **Context:** Disabling WhatsApp in Nix `settings.nix` after a failed deploy.
- **Error:** Gateway still tried WhatsApp despite `WHATSAPP_ENABLED=false`.
- **Cause:** NixOS activation deep-merges into existing `config.yaml`; removing keys from Nix does not delete them from the on-disk file.
- **Fix:** Back up and remove `/var/lib/hermes/.hermes/config.yaml`, then rebuild/restart so activation writes a fresh file from Nix settings only.
- **Avoid:** Assuming comment-out in `settings.nix` alone disables a platform that was previously merged in.
