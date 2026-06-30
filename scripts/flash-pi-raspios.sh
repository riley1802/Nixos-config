#!/usr/bin/env bash
# Flash Raspberry Pi OS Lite (64-bit) to USB/SD — works on Pi 4 USB boot without an SD reader.
# Uses curl + dd (reliable on slow USB) then injects cloud-init for SSH.
set -euo pipefail

DEVICE="${1:-}"
IMG_URL="${IMG_URL:-https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2026-06-19/2026-06-18-raspios-trixie-arm64-lite.img.xz}"
WORKDIR="${WORKDIR:-/tmp/pi-raspios}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUDINIT="${SCRIPT_DIR}/pi-raspios-cloudinit.yaml"
NETWORK_CONFIG="${SCRIPT_DIR}/pi-raspios-network-config.yaml"
IMG_XZ="${WORKDIR}/raspios-lite-arm64.img.xz"
IMG="${WORKDIR}/raspios-lite-arm64.img"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

if [[ -z "${DEVICE}" ]]; then
  echo "Usage: sudo $0 /dev/sdX" >&2
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Re-run with sudo." >&2
  exit 1
fi

if [[ "${DEVICE}" =~ [0-9]$ ]]; then
  echo "Error: pass whole disk (${DEVICE%[0-9]*}), not a partition." >&2
  exit 1
fi

for f in "${CLOUDINIT}" "${NETWORK_CONFIG}"; do
  [[ -f "${f}" ]] || { echo "Missing ${f}" >&2; exit 1; }
done

unmount_partitions() {
  local dev="$1"
  if ! lsblk -ln -o MOUNTPOINT "${dev}"?* "${dev}"p* 2>/dev/null | grep -q '^/'; then
    log "No partitions mounted on ${dev}, skipping unmount."
    return 0
  fi
  local part
  for part in "${dev}"?* "${dev}"p*; do
    [[ -e "${part}" ]] || continue
    findmnt "${part}" >/dev/null 2>&1 || continue
    log "Unmounting ${part}..."
    umount -lf "${part}" 2>/dev/null || true
  done
  sync
}

prepare_image() {
  mkdir -p "${WORKDIR}"
  if [[ ! -f "${IMG_XZ}" ]]; then
    log "Downloading Pi OS Lite (~500MB compressed)..."
    curl -fL --progress-bar -o "${IMG_XZ}" "${IMG_URL}"
  else
    log "Using cached ${IMG_XZ}"
  fi
  if [[ ! -f "${IMG}" ]]; then
    log "Decompressing (one-time, ~2GB)..."
    nix shell nixpkgs#xz -c unxz -f -k "${IMG_XZ}"
    mv -f "${IMG_XZ%.xz}" "${IMG}"
  else
    log "Using cached ${IMG}"
  fi
}

inject_cloud_init() {
  local boot_part="$1"
  local mnt
  mnt="$(mktemp -d /tmp/piboot.XXXXXX)"
  log "Mounting ${boot_part} to inject SSH / cloud-init..."
  mount -o rw "${boot_part}" "${mnt}"
  cp "${CLOUDINIT}" "${mnt}/user-data"
  cp "${NETWORK_CONFIG}" "${mnt}/network-config"
  echo "instance-id: nixos-pi-$(date +%s)" > "${mnt}/meta-data"
  touch "${mnt}/ssh"
  sync
  umount "${mnt}"
  rmdir "${mnt}"
}

log "Target:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL,TRAN "${DEVICE}" || true

unmount_partitions "${DEVICE}"

if lsblk -ln -o MOUNTPOINT "${DEVICE}"?* "${DEVICE}"p* 2>/dev/null | grep -q '^/'; then
  warn "Partitions still mounted — unplug/replug USB and retry."
  exit 1
fi

prepare_image

img_size="$(stat -c '%s' "${IMG}")"
log "Writing ${img_size} bytes to ${DEVICE} with dd (~10–15 min on this USB)..."
dd if="${IMG}" of="${DEVICE}" bs=4M status=progress iflag=fullblock

log "Flushing..."
blockdev --flushbufs "${DEVICE}" 2>/dev/null || true
sync

blockdev --rereadpt "${DEVICE}" 2>/dev/null || true
partprobe "${DEVICE}" 2>/dev/null || true
sleep 2

BOOT_PART="${DEVICE}1"
if [[ ! -b "${BOOT_PART}" ]]; then
  warn "Expected boot partition ${BOOT_PART} missing after flash."
  lsblk "${DEVICE}"
  exit 1
fi

inject_cloud_init "${BOOT_PART}"

lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "${DEVICE}"

log "Done."
log "1. Plug USB into Pi 4 (USB 3), ethernet, power on."
log "2. Wait ~2 min, then: ssh rileyt@nixos-pi.local"
log "3. Install NixOS: bash /etc/nixos/scripts/install-nixos-on-pi.sh (after cloning repo)"
