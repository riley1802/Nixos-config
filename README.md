# NixOS Config

Personal NixOS flake for two hosts:

| Host | Platform | Role |
|------|----------|------|
| `nixos` | x86_64 | Desktop workstation (GNOME, NVIDIA, local AI) |
| `nixos-pi` | aarch64 (Raspberry Pi 4) | Homelab infocenter (XFCE, dashboards) |

System configuration lives under `hosts/` and `modules/`. User configuration
lives under `home/`.

## Layout

- `flake.nix` - flake inputs and `nixos` / `nixos-pi` outputs.
- `hosts/<hostname>/` - per-host `configuration.nix` and `hardware-configuration.nix`.
- `configuration.nix` - re-exports `hosts/nixos/` for compatibility.
- `home.nix` - Home Manager imports for the desktop.
- `home/home-pi.nix` - lightweight Home Manager imports for the Pi.
- `modules/core/` - boot, locale, networking, and system defaults.
- `modules/desktop/` - GNOME (desktop) and XFCE (Pi).
- `modules/hardware/` - NVIDIA (desktop) and Raspberry Pi 4.
- `modules/programs/` - system-level applications and program settings.
- `modules/services/` - system services.
- `modules/users/` - local user accounts.
- `secrets/` - agenix-encrypted secrets (`*.age`) and `secrets.nix` public keys.
- `home/` - Home Manager modules for user packages and desktop preferences.

## Raspberry Pi 4 (`nixos-pi`)

Homelab infocenter node: XFCE desktop, Homepage dashboard, Uptime Kuma, and
Tailscale. Heavy desktop services (llama.cpp, SearXNG, NVIDIA, gaming) stay on
`nixos` only.

| Service | URL | Module |
|---------|-----|--------|
| Homepage | http://127.0.0.1:8082 | `modules/services/homepage.nix` |
| Uptime Kuma | http://127.0.0.1:3001 | `modules/services/uptime-kuma.nix` |
| Tailscale | tailnet (MagicDNS) | `modules/services/tailscale.nix` |

### No SD card reader? Use Raspberry Pi OS on USB

The generic NixOS bootstrap image **does not boot reliably from USB** on Pi 4.
Without an SD reader, flash **Raspberry Pi OS Lite** to your USB stick instead,
boot the Pi, then install your NixOS flake on the running Pi.

**On your desktop** (replaces the NixOS bootstrap on the USB):

```sh
chmod +x /etc/nixos/scripts/flash-pi-raspios.sh
sudo /etc/nixos/scripts/flash-pi-raspios.sh /dev/sdb
```

**On the Pi** (after ~2 min boot, ethernet connected):

```sh
ssh rileyt@nixos-pi.local
curl -fsSL https://raw.githubusercontent.com/riley1802/Nixos-config/main/scripts/install-nixos-on-pi.sh | bash
```

Or copy `scripts/install-nixos-on-pi.sh` from the repo after cloning. First build
takes ~20–40 minutes on the Pi. Copy your `~/.ssh/id_ed25519` from the desktop
before the rebuild so agenix can decrypt Tailscale secrets:

```sh
scp ~/.ssh/id_ed25519 rileyt@nixos-pi.local:~/.ssh/
```

### First-time install (build on the Pi — not the desktop)

**Do not** build the Pi image on your x86 desktop. Emulating aarch64 compiles the
entire Pi kernel under QEMU and can peg the CPU for hours. Instead:

1. Flash a small **prebuilt bootstrap image** (download only, ~2 minutes).
2. Boot the Pi from USB/SD.
3. Run `nixos-rebuild switch --flake .#nixos-pi` **on the Pi** (native aarch64).

The first `nixos-rebuild` on the Pi still compiles the Pi kernel once, but runs
at full native speed (typically 20–40 minutes, not hours). Later rebuilds are
mostly cached.

#### 1. Flash the USB drive (on the desktop)

Your drive is `/dev/sdb` (whole disk). Use `/dev/sdb`, **not** `/dev/sdb2`.

```sh
cd /etc/nixos
chmod +x scripts/flash-pi-bootstrap.sh
sudo ./scripts/flash-pi-bootstrap.sh /dev/sdb
```

This downloads the official Hydra aarch64 image (NixOS 25.11 minimal) and
writes it to the USB stick. It is only a bootstrap — your flake replaces
everything on first rebuild.

#### 2. Boot the Pi

**Use a microSD card in the Pi's SD slot if you have one** — it is far more reliable
than USB for the generic bootstrap image.

1. Insert the flashed media (SD card preferred; USB 3.0 port if not).
2. Connect **ethernet** and a **good power supply** (official 3A USB-C).
3. Power on.

If the screen shows Raspberry Pi **stage 1 / stage 2** then goes black and the Pi
shuts off, the generic bootstrap image cannot mount root from USB. See
[Troubleshooting Pi boot](#troubleshooting-pi-boot) below.

#### 3. Find the Pi and SSH in (bootstrap login)

The bootstrap image ships a `nixos` user. Check your router for the Pi's IP, or try:

```sh
ssh nixos@nixos-pi.local
# password: nixos
```

#### 4. Clone this repo on the Pi

```sh
sudo mkdir -p /etc/nixos
sudo chown nixos:users /etc/nixos
git clone https://github.com/riley1802/Nixos-config.git /etc/nixos
cd /etc/nixos
```

Copy your age identity so agenix can decrypt secrets (from the desktop):

```sh
# Run on the DESKTOP — copies your user key to the Pi
scp ~/.ssh/id_ed25519 nixos@<pi-ip>:~/.ssh/
ssh nixos@<pi-ip> 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_ed25519'
```

#### 5. Apply your full config (on the Pi)

```sh
ssh nixos@<pi-ip>
cd /etc/nixos
sudo nixos-rebuild switch --flake .#nixos-pi --impure
```

`--impure` is required so the flake can read the predetermined host key at
`/etc/nixos/secrets/nixos-pi-ssh-host-key` (gitignored, stays on disk only).

This step builds natively on the Pi. Go get coffee — not hours on your desktop.

After it finishes you will have user `rileyt`, XFCE, Homepage, Uptime Kuma,
Tailscale, and SSH on LAN + tailnet. Log in with:

```sh
ssh rileyt@nixos-pi.local
# or: ssh rileyt@<pi-ip>
```

#### 6. Remote rebuilds from the desktop (after first boot)

Once the Pi is on your config, deploy updates without building on the desktop:

```sh
nixos-rebuild switch --flake /etc/nixos#nixos-pi \
  --target-host rileyt@nixos-pi --use-remote-sudo --impure
```

Nix builds on the Pi, not your x86 machine.

### Troubleshooting Pi boot

The Hydra bootstrap image is a **generic** aarch64 NixOS image. It often **fails
to boot from USB** on a Pi 4 (stage 1 / stage 2, then black screen or power off)
because the Pi needs extra firmware, kernel, and initrd modules that only exist in
your full `nixos-pi` flake — which you cannot apply until the Pi boots once.

**Try these in order:**

1. **microSD card** — Re-flash the same bootstrap image to an SD card, insert it
   in the Pi's **SD slot** (not USB), and boot. This works for most people.

2. **USB boot EEPROM** — If you must use USB, the Pi 4 EEPROM must support USB
   boot. On another machine, use [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
   → Choose OS → Misc utility images → Bootloader → USB Boot, flash to a spare SD,
   boot the Pi once to update EEPROM, then retry your USB stick.

3. **Raspberry Pi OS bridge (most reliable)** — Boot official Pi OS Lite 64-bit,
   then install NixOS from your flake on the running Pi:
   ```sh
   # On Pi OS (after ethernet works)
   curl -L https://nixos.org/nix/install | sh
   . ~/.nix-profile/etc/profile.d/nix.sh
   sudo mkdir -p /etc/nixos && sudo chown $USER /etc/nixos
   git clone https://github.com/riley1802/Nixos-config.git /etc/nixos
   cd /etc/nixos
   # Copy id_ed25519 from desktop for agenix
   sudo nixos-rebuild switch --flake .#nixos-pi --impure
   ```
   This skips the broken bootstrap entirely and builds your real Pi config natively.

4. **Power** — Use the official 3A USB-C supply. Under-powered Pis fail during boot
   with no clear error.

### Ongoing Pi updates

```sh
# From the Pi
sudo nixos-rebuild switch --flake .#nixos-pi

# Or remotely from the desktop
nixos-rebuild switch --flake .#nixos-pi --target-host rileyt@nixos-pi --use-remote-sudo
```

## Local AI Stack (desktop only)

This system runs llama.cpp for local inference and SearXNG for search, both
bound to localhost.

| Service | URL | Module |
|---------|-----|--------|
| llama.cpp API | http://127.0.0.1:8080/v1 | `modules/services/llama-cpp.nix` |
| SearXNG | http://127.0.0.1:8888 | `modules/services/searxng.nix` |
| Tailscale | tailnet (MagicDNS) | `modules/services/tailscale.nix` |

### llama.cpp

- CUDA build from `nixpkgs-unstable` (llama.cpp 9747+), required for Gemma 4
  Multi-Token Prediction (MTP).
- Dual-GPU layer split across RTX 3050 and GTX 1660 Super.
- Models are stored in `/var/lib/llama-cpp/models` and survive NixOS upgrades.
- Models download automatically from Hugging Face on first use.

Configured model presets:

| Alias | Model | Notes |
|-------|-------|-------|
| `gemma-4-e4b-q8` | Gemma 4 E4B Q8_0 | Fast, smaller model |
| `nemotron-nano-12b-v2-q4` | Nemotron Nano 12B v2 Q4_K_M | NVIDIA reasoning model |
| `gemma-4-12b-q4-mtp` | Gemma 4 12B Q4_K_M + MTP drafter | ~27% faster than baseline on this hardware |

Switch the active model by restarting the service with a different preset alias
in `modules/services/llama-cpp.nix`.

### SearXNG

- Local meta-search engine with JSON output.
- Secret key managed by agenix (`secrets/searxng-secret-key.age`).

### Tailscale

- Mesh VPN via `services.tailscale`.
- Auth key managed by agenix (`secrets/tailscale-auth-key.age`).
- SSH (`port 22`) allowed on `tailscale0` only — not open on LAN/WAN.
- Connect remotely: `ssh rileyt@nixos` from another tailnet device.
- **After revoking a key in Tailscale admin**, create a new key and run `agenix -e secrets/tailscale-auth-key.age` before rebuilding.

## Firewall policy

Services do not open the public firewall unless explicitly intended:

| Service | Firewall |
|---------|----------|
| SSH | `tailscale0` only (port 22) |
| llama.cpp, SearXNG | localhost only (desktop) |
| Homepage, Uptime Kuma | localhost only (Pi) |
| Tailscale | closed (`openFirewall = false`) |
| Steam Remote Play | closed (`remotePlay.openFirewall = false`) |

## Secrets (agenix)

All secrets use [agenix](https://github.com/ryantm/agenix). Encrypted files in `secrets/` are safe to commit; decrypted copies live in `/run/agenix/` at activation only.

| Secret | File |
|--------|------|
| Tailscale auth key | `secrets/tailscale-auth-key.age` |
| SearXNG secret key | `secrets/searxng-secret-key.age` |

Edit secrets:

```sh
nix shell github:ryantm/agenix
cd /etc/nixos/secrets
agenix -e tailscale-auth-key.age
```

Full instructions: [secrets/README.md](secrets/README.md)

Create or rotate a Tailscale key at [Tailscale admin → Keys](https://login.tailscale.com/admin/settings/keys), then `agenix -e secrets/tailscale-auth-key.age`. Do not paste keys in chat.

## Usage

Apply the desktop configuration:

```sh
sudo nixos-rebuild switch --flake .#nixos
```

Build the desktop system without switching:

```sh
nix build .#nixosConfigurations.nixos.config.system.build.toplevel
```

Flash the Pi bootstrap USB image:

```sh
sudo /etc/nixos/scripts/flash-pi-bootstrap.sh /dev/sdb
```

Update locked inputs:

```sh
nix flake update
sudo nixos-rebuild switch --flake .#nixos
```

Format Nix files:

```sh
nix fmt
```

Check service status after applying:

```sh
systemctl status llama-cpp searx tailscaled
curl http://127.0.0.1:8080/v1/models
curl http://127.0.0.1:8888
tailscale status
```

## Git and GitHub

This repo uses the GitHub CLI (`gh`) as a credential helper so `git push` and
`git pull` work without entering a username or password each time.

Remote:

```sh
https://github.com/riley1802/Nixos-config.git
```

One-time setup on a new machine:

```sh
nix shell nixpkgs#gh
gh auth login
gh auth setup-git
```

Verify:

```sh
git pull
git push
```

The `gh` token is stored in the system keyring and refreshed automatically.

### SSH (optional)

SSH is also configured at `~/.ssh/id_ed25519`. To use it instead of HTTPS:

```sh
git remote set-url origin git@github.com:riley1802/Nixos-config.git
gh auth refresh -h github.com -s admin:public_key
gh ssh-key add ~/.ssh/id_ed25519.pub --title "nixos-$(hostname)"
ssh -T git@github.com
```

## Publishing Notes

Before pushing this repository publicly, review machine-specific files:

- `hardware-configuration.nix` includes disk UUIDs and hardware details.
- `modules/core/networking.nix` includes the hostname.
- `modules/users/rileyt.nix` includes the local username and groups.
- Do not commit private keys, access tokens, age identities, or plaintext credentials.
- Encrypted `secrets/*.age` files **are** intended for git (agenix).

Commit secrets only via agenix-encrypted `.age` files. Keep decryption keys (SSH host key, user key) off GitHub.
