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
