# Lessons Learned

Errors and fixes from past NixOS work on this machine. **Append a new entry whenever a build, rebuild, or runtime error is hit and resolved.** Check this file before repeating a similar change.

## Entry format

```markdown
### YYYY-MM-DD — Short title

**Context:** What we were trying to do.

**Error:** Exact message or symptom.

**Cause:** Why it happened.

**Fix:** What worked.

**Avoid:** Rule to prevent recurrence.
```

---

### 2026-06 — Stable llama.cpp missing Gemma 4 MTP

**Context:** Enable Gemma 4 12B with multi-token prediction on dual GPUs.

**Error:** Model loaded but MTP / `gemma4-assistant` features unavailable on stable llama.cpp build.

**Cause:** Stable nixpkgs llama.cpp too old; MTP support only in newer builds.

**Fix:** Use `pkgsUnstable.llama-cpp` with `cudaSupport = true` in `modules/services/llama-cpp.nix`.

**Avoid:** Do not assume stable nixpkgs has latest llama.cpp features — check version, use `pkgsUnstable` when needed.

---

### 2026-06 — Packaging .deb fails on setuid bit

**Context:** Package Goose desktop from official `.deb`.

**Error:** `dpkg-deb` unpack failed — setuid bit on `chrome-sandbox` not allowed in Nix sandbox.

**Cause:** Debian package ships setuid binary; Nix sandbox rejects permission restoration.

**Fix:** Unpack with `ar x` + `tar --no-same-owner --no-same-permissions --zstd -xf data.tar.zst -C source`.

**Avoid:** Prefer `ar`/`tar` over `dpkg-deb -x` for Electron `.deb` packages in Nix derivations.

---

### 2026-06 — Custom unpack breaks sourceRoot

**Context:** Same Goose desktop derivation.

**Error:** `find: 'source': No such file or directory` during build.

**Cause:** Unpack phase `cd source` before extraction; `sourceRoot = "source"` expects contents inside `source/`.

**Fix:** `mkdir source` then extract with `-C source`; do not `cd` into source during unpack.

**Avoid:** When overriding `unpackPhase`, always extract *into* `$sourceRoot`, not the working directory.

---

### 2026-06 — auto-patchelf missing libasound for Electron

**Context:** Building Goose desktop after unpack fix.

**Error:** `auto-patchelf could not satisfy dependency libasound.so.2`.

**Cause:** Electron binary links ALSA at runtime; not in buildInputs.

**Fix:** Add `alsa-lib` to `buildInputs`.

**Avoid:** Electron/app packages need `alsa-lib` in buildInputs for autoPatchelfHook.

---

### 2026-06 — Electron EGL dlopen at runtime

**Context:** Launching packaged Electron app on Wayland.

**Error:** `Could not dlopen native EGL: libEGL.so.1: cannot open shared object file`.

**Cause:** Electron dlopens `libEGL.so.1` at runtime; auto-patchelf only patches linked deps, not dlopen.

**Fix:** Add `libglvnd` to buildInputs; set `--prefix LD_LIBRARY_PATH` on wrapper including `makeLibraryPath buildInputs` and app lib dir.

**Avoid:** Wrapped Electron apps need explicit `LD_LIBRARY_PATH` for EGL/GL libraries.

---

### 2026-06 — Home Manager clobbers existing Goose config

**Context:** Deploy Goose config via Home Manager.

**Error:** HM activation conflict — files already exist in `~/.config/goose/`.

**Cause:** User had prior Goose config; HM refuses to overwrite by default.

**Fix:** Set `force = true` on managed `xdg.configFile` entries.

**Avoid:** Any HM-managed dotfile that may exist on disk needs `force = true`.

---

### 2026-06 — gnome-terminal launcher D-Bus failure

**Context:** Goose CLI desktop entry using `gnome-terminal`.

**Error:** `The name is not activatable` — app menu launcher did nothing.

**Cause:** `gnome-terminal` D-Bus activation unreliable from desktop entries on this GNOME/Wayland setup.

**Fix:** Use `kgx` (GNOME Console) via a `goose-launch` wrapper script.

**Avoid:** Prefer `kgx` over `gnome-terminal` for HM desktop entries that open terminal apps.

---

### 2026-06 — Agent cannot sudo rebuild interactively

**Context:** Cursor agent runs `nixos-rebuild switch`.

**Error:** `sudo: a terminal is required to read the password`.

**Cause:** Non-interactive agent shell has no password prompt.

**Fix:** Run rebuild sequence; if sudo fails, give user the exact command to run locally.

**Avoid:** Never assume sudo works in agent context — always have a fallback command ready.

---

### 2026-06 — Flake ignores untracked new modules

**Context:** Added new `.nix` module files for Tailscale and agenix.

**Error:** `Path 'modules/core/openssh.nix' in the repository is not tracked by Git`.

**Cause:** Nix flakes only copy git-tracked files into the store.

**Fix:** `git add` new files before `nix flake check` or rebuild.

**Avoid:** Always stage new modules before validating or rebuilding.

---

### 2026-06 — Revoked Tailscale auth key fails rebuild

**Context:** Tailscale auth key revoked in admin after being set in agenix.

**Error:** `tailscaled-autoconnect.service` failed — `invalid key: unable to validate API key`; `nixos-rebuild switch` exit 4.

**Cause:** `secrets/tailscale-auth-key.age` still contained the revoked key.

**Fix:** Create new auth key in Tailscale admin → `agenix -e secrets/tailscale-auth-key.age` → rebuild.

**Avoid:** Rotate keys only via agenix; never paste keys in chat; update secret before rebuild after revoking.

---

### 2026-06 — Placeholder Tailscale auth key

**Context:** Initial agenix setup with placeholder text in `tailscale-auth-key.age`.

**Error:** Same as revoked key — `invalid key: unable to validate API key`.

**Cause:** Placeholder is not a valid Tailscale auth key.

**Fix:** Replace with real key via `agenix -e`.

**Avoid:** Never commit or deploy without a valid encrypted auth key when `authKeyFile` is set.
