#!/usr/bin/env bash
# Flash Raspberry Pi OS Lite (64-bit) to USB/SD — works on Pi 4 USB boot without an SD reader.
# After boot: ssh rileyt@nixos-pi.local → install NixOS flake (see README).
set -euo pipefail

DEVICE="${1:-}"
IMG_URL="${IMG_URL:-https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2026-06-19/2026-06-18-raspios-trixie-arm64-lite.img.xz}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUDINIT="${SCRIPT_DIR}/pi-raspios-cloudinit.yaml"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

if [[ -z "${DEVICE}" ]]; then
  echo "Usage: sudo $0 /dev/sdX" >&2
  echo "       Whole disk only (e.g. /dev/sdb), not a partition." >&2
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Re-run with sudo." >&2
  exit 1
fi

if [[ "${DEVICE}" =~ [0-9]$ ]]; then
  echo "Error: pass whole disk (${DEVICE%[0-9]*}), not partition (${DEVICE})." >&2
  exit 1
fi

if [[ ! -f "${CLOUDINIT}" ]]; then
  echo "Missing ${CLOUDINIT}" >&2
  exit 1
fi

log "Target:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL,TRAN "${DEVICE}" || true

log "Unmounting ${DEVICE}..."
umount -lf "${DEVICE}"* 2>/dev/null || true
sync

if lsblk -ln -o MOUNTPOINT "${DEVICE}"* 2>/dev/null | rg -q '^/'; then
  warn "Partitions still mounted — unplug/replug USB and retry."
  exit 1
fi

log "Flashing Raspberry Pi OS Lite (64-bit) with SSH for rileyt..."
log "Image: ${IMG_URL}"
log "This downloads ~500MB and takes 10–20 minutes."

nix run nixpkgs#rpi-imager -- \
  --cli \
  --enable-writing-system-drives \
  --cloudinit-userdata "${CLOUDINIT}" \
  "${IMG_URL}" \
  "${DEVICE}"

sync
log "Done."
log "1. Plug USB into Pi 4 (USB 3 port), connect ethernet, power on."
log "2. Wait ~2 minutes, then: ssh rileyt@nixos-pi.local"
log "3. Install NixOS: see README 'Raspberry Pi OS bridge'."
