# User preferences & decisions

Standing preferences for agents working on this flake. Update when Riley
changes a decision. Read this before multi-host, git, or laptop/desktop work.

## Source of truth

| Rule | Detail |
|------|--------|
| **GitHub is the source of truth** | Remote: `https://github.com/riley1802/Nixos-config.git` (`main`). Local `/etc/nixos` on every machine is a checkout of that repo — not an independent config. |
| **If it is not on GitHub, it is not finished** | Validated changes that should apply to the fleet must be committed **and pushed** so both hosts can pull the same tree. |
| **Pull before rebuild on the other host** | After pushing from one machine, the other must `git pull` (or equivalent) before `nixos-rebuild` so it does not rebuild stale config. |
| **Ask before push** | Default: ask once before `git push` to `main`. Exception: Riley already directed "push", "commit to GitHub", or "repo is the source of truth" for the current work — then push after a successful commit. |

## Seamless desktop + laptop

Goal: one flake, same service stack and Home Manager commons, host-specific
only where hardware or desktop environment truly differs. Working on either
machine should feel like the same system.

| Preference | Decision |
|------------|----------|
| Shared stack | `hosts/common.nix` + `home/common.nix` — full AI/dashboard/services stack on every host unless a host explicitly opts out. |
| Per-host deltas | Only in `hosts/<name>/` and via `host.*` options in `modules/core/host-facts.nix` (e.g. `host.gpus`, `host.uptimeKumaSync`, `host.tailnetName`). |
| Desktops | `nixos` (desktop): GNOME + GDM. `legion` (laptop): Cinnamon + LightDM (X11). |
| GPU / Legion | PRIME **offload** (`modules/hardware/nvidia-prime.nix`). BIOS **GPU Working Mode = Hybrid** (not Discrete). Discrete muxes the panel to NVIDIA and black-screens the X11 offload greeter. |
| Secrets | Every host that runs the shared stack must be able to decrypt the same agenix secrets. Adding a host key to `secrets/secrets.nix` is incomplete until `agenix -r` runs on a machine that can already decrypt, then push the rekeyed `.age` files. |
| Auth / git | Declarative git identity + `gh` credential helper in `home/programs/git.nix` so commits/pushes work the same on both hosts without hand-editing HM-managed git config. |
| Remote access | Tailscale + Tailscale Serve for HTTPS front ends; SSH only on `tailscale0`. Prefer Tailscale over ad-hoc LAN exposure. |

## Session decisions (2026-07-18 legion bring-up)

Recorded so agents do not re-litigate them:

1. **Generation 6 black screen** — cause was BIOS Discrete + PRIME offload; fix was Hybrid BIOS, not rewriting the NixOS GPU module.
2. **whisper.cpp crash-loop on fresh host** — unit PATH must include deps of the first-run model download (`coreutils`, `gnugrep`), not only steady-state tools.
3. **agenix on a new host** — cannot rekey from the new machine alone; rekey on an existing host (desktop), push, pull, rebuild.
4. **`gh auth login` vs HM git config** — never tell the user to edit `~/.config/git/config` by hand; declare credential helpers in `home/programs/git.nix`.
5. **Uptime Kuma sync on legion** — left `host.uptimeKumaSync = false` until a Kuma admin account exists and the sync secret is ready.
6. **Cross-host agent work** — Riley may authorize SSH from laptop → desktop (or vice versa) to finish fleet tasks (rekey, sync). Prefer passwordless key after a one-time `ssh-copy-id`; do not ask him to paste passwords into chat.

## Agent behavior summary

- Prefer shared modules; put host-only quirks in host configs / `host.*` options.
- After multi-host-relevant fixes: validate → commit → push (per source-of-truth rules) → remind to pull + rebuild on the other machine when needed.
- Keep README, `reference/`, and `lessons.md` in sync so both machines' agents see the same policy.
- Never treat one host's unpushed working tree as authoritative for the other.
