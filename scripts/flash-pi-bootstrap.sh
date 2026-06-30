#!/usr/bin/env bash
# Flash a prebuilt NixOS aarch64 bootstrap image to a USB/SD device.
# Your full nixos-pi config is applied later via `nixos-rebuild` ON THE PI.
set -euo pipefail

DEVICE="${1:-}"
HYDRA_URL="${HYDRA_URL:-https://hydra.nixos.org/build/333508762/download/1/nixos-image-sd-card-25.11.12453.0a47451dbe20-aarch64-linux.img.zst}"
WORKDIR="${WORKDIR:-/tmp/nixos-pi-bootstrap}"
IMG_ZST="${WORKDIR}/nixos-bootstrap.img.zst"
IMG="${WORKDIR}/nixos-bootstrap.img"

if [[ -z "${DEVICE}" ]]; then
  echo "Usage: sudo $0 /dev/sdX" >&2
  echo "       (whole disk, e.g. /dev/sdb — NOT a partition like /dev/sdb2)" >&2
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Re-run with sudo." >&2
  exit 1
fi

if [[ "${DEVICE}" =~ [0-9]$ ]]; then
  echo "Error: pass the whole disk (${DEVICE%[0-9]*}), not a partition (${DEVICE})." >&2
  exit 1
fi

mkdir -p "${WORKDIR}"

if [[ ! -f "${IMG_ZST}" ]]; then
  echo "Downloading bootstrap image..."
  curl -fL --progress-bar -o "${IMG_ZST}" "${HYDRA_URL}"
fi

if [[ ! -f "${IMG}" ]]; then
  echo "Decompressing..."
  nix shell nixpkgs#zstd -c unzstd -f "${IMG_ZST}" -o "${IMG}"
fi

echo "Unmounting ${DEVICE}* ..."
umount -R "${DEVICE}"* 2>/dev/null || true

echo "Writing to ${DEVICE} (all data on this disk will be erased)..."
dd if="${IMG}" of="${DEVICE}" bs=4M status=progress conv=fsync

sync
echo "Done. Safely remove the drive, plug it into the Pi USB port, connect ethernet, and boot."
