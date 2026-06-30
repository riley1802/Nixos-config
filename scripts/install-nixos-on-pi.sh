#!/usr/bin/env bash
# Run ON THE PI after Raspberry Pi OS boots (as rileyt).
# Installs Nix and switches to the nixos-pi flake configuration.
set -euo pipefail

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "This script must run on the Raspberry Pi (aarch64)." >&2
  exit 1
fi

if ! command -v curl >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y curl git
fi

if ! command -v nix >/dev/null; then
  log "Installing Nix..."
  curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

if [[ ! -d /etc/nixos/.git ]]; then
  log "Cloning NixOS config..."
  sudo mkdir -p /etc/nixos
  sudo chown rileyt:rileyt /etc/nixos
  git clone https://github.com/riley1802/Nixos-config.git /etc/nixos
fi

if [[ ! -f /home/rileyt/.ssh/id_ed25519 ]]; then
  warn "Copy your age/SSH key from the desktop:"
  warn "  scp nixos:~/.ssh/id_ed25519 rileyt@nixos-pi:~/.ssh/"
  warn "Continuing without it — agenix secrets may fail."
fi

cd /etc/nixos
log "Building nixos-pi configuration (native aarch64, ~20–40 min first time)..."
sudo -E env PATH="$PATH" nixos-rebuild switch --flake .#nixos-pi --impure

log "Done. Reboot recommended: sudo reboot"
log "Then: ssh rileyt@nixos-pi.local"
