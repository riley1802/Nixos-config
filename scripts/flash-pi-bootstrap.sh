#!/usr/bin/env bash
# Flash a prebuilt NixOS aarch64 bootstrap image to a USB/SD device.
# Your full nixos-pi config is applied later via `nixos-rebuild` ON THE PI.
set -euo pipefail

DEVICE="${1:-}"
MODE="${MODE:-flash}" # flash | check
HYDRA_URL="${HYDRA_URL:-https://hydra.nixos.org/build/333508762/download/1/nixos-image-sd-card-25.11.12453.0a47451dbe20-aarch64-linux.img.zst}"
WORKDIR="${WORKDIR:-/tmp/nixos-pi-bootstrap}"
IMG_ZST="${WORKDIR}/nixos-bootstrap.img.zst"
IMG="${WORKDIR}/nixos-bootstrap.img"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage:
  sudo $0 /dev/sdX          Flash bootstrap image to whole disk
  sudo MODE=check $0 /dev/sdX   Check device / in-progress flash only

Pass the whole disk (e.g. /dev/sdb), NOT a partition (/dev/sdb2).
EOF
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Re-run with sudo." >&2
    exit 1
  fi
}

validate_device() {
  if [[ -z "${DEVICE}" ]]; then
    usage >&2
    exit 1
  fi

  if [[ "${DEVICE}" =~ [0-9]$ ]]; then
    echo "Error: pass the whole disk (${DEVICE%[0-9]*}), not a partition (${DEVICE})." >&2
    exit 1
  fi

  if [[ ! -b "${DEVICE}" ]]; then
    echo "Error: ${DEVICE} is not a block device." >&2
    exit 1
  fi
}

show_device_info() {
  log "Target device:"
  lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL,TRAN "${DEVICE}" || true
  echo
}

unmount_device() {
  log "Unmounting ${DEVICE} and all partitions..."
  umount -lf "${DEVICE}"* 2>/dev/null || true
  sync
}

image_bytes() {
  stat -c '%s' "${IMG}"
}

check_flash_process() {
  local pid img_size copied
  pid="$(pgrep -xn dd 2>/dev/null || true)"
  if [[ -z "${pid}" ]]; then
    log "No dd process running."
    return 0
  fi
  if tr '\0' ' ' < "/proc/${pid}/cmdline" | rg -q "of=${DEVICE}"; then
    log "dd is running (pid ${pid}) for ${DEVICE}"
    tr '\0' ' ' < "/proc/${pid}/cmdline"
    echo
    if [[ -f "${IMG}" ]]; then
      img_size="$(image_bytes)"
      # dd progress line is not in proc; report kernel I/O wait state.
      state="$(ps -o stat= -p "${pid}" | tr -d ' ')"
      log "Process state: ${state} (D = waiting on USB flush — normal after write completes)"
      log "Image size: ${img_size} bytes"
      if [[ "${state}" == D* ]]; then
        log "Write likely finished; flushing to USB. This can take 5–20 min on slow sticks."
      fi
    fi
  else
    log "dd is running but not targeting ${DEVICE}"
  fi
}

check_device_image() {
  if [[ ! -b "${DEVICE}" ]]; then
    return 1
  fi
  log "First sectors of ${DEVICE}:"
  file -s "${DEVICE}"
  lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "${DEVICE}"
}

prepare_image() {
  mkdir -p "${WORKDIR}"

  if [[ ! -f "${IMG_ZST}" ]]; then
    log "Downloading bootstrap image..."
    curl -fL --progress-bar -o "${IMG_ZST}" "${HYDRA_URL}"
  else
    log "Using cached ${IMG_ZST}"
  fi

  if [[ ! -f "${IMG}" ]]; then
    log "Decompressing (one-time)..."
    nix shell nixpkgs#zstd -c unzstd -f "${IMG_ZST}" -o "${IMG}"
  else
    log "Using cached ${IMG}"
  fi

  log "Image size: $(image_bytes) bytes ($(numfmt --to=iec-i --suffix=B "$(image_bytes)" 2>/dev/null || image_bytes))"
}

flash_device() {
  local img_size
  img_size="$(image_bytes)"

  show_device_info
  unmount_device

  sync

  # Only block if a partition still has a live mountpoint.
  if lsblk -ln -o MOUNTPOINT "${DEVICE}"* 2>/dev/null | rg -q '^/'; then
    warn "Partitions still mounted:"
    lsblk -o NAME,MOUNTPOINT "${DEVICE}"
    warn "Trying lazy unmount..."
    umount -lf "${DEVICE}"* 2>/dev/null || true
    sync
  fi

  if lsblk -ln -o MOUNTPOINT "${DEVICE}"* 2>/dev/null | rg -q '^/'; then
    warn "Could not unmount ${DEVICE}. Unplug/replug the USB, then retry."
    exit 1
  fi

  log "Writing ${img_size} bytes to ${DEVICE} (all data erased)..."
  log "Write phase: progress below updates while copying."
  # Do NOT use conv=fsync here — it hides progress during a long silent USB flush.
  dd if="${IMG}" of="${DEVICE}" bs=4M status=progress iflag=fullblock

  log "Write complete. Flushing buffers to USB (may take several minutes on slow drives)..."
  blockdev --flushbufs "${DEVICE}" 2>/dev/null || true
  sync

  log "Verifying partition table visible..."
  partprobe "${DEVICE}" 2>/dev/null || true
  sleep 1
  lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "${DEVICE}"

  log "Done. Safely remove the drive, plug it into the Pi USB port, connect ethernet, and boot."
  log "Bootstrap login: ssh nixos@nixos-pi.local  (password: nixos)"
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  DEVICE="${1:-}"
  validate_device

  case "${MODE}" in
    check)
      require_root
      show_device_info
      check_flash_process
      check_device_image
      ;;
    flash)
      require_root
      prepare_image
      flash_device
      ;;
    *)
      echo "Unknown MODE=${MODE} (use flash or check)" >&2
      exit 1
      ;;
  esac
}

main "$@"
