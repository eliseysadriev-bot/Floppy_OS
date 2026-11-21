#!/usr/bin/env bash
# Floppy OS 1.1 launcher for Linux
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

QEMU="${QEMU:-qemu-system-i386}"
if ! command -v "$QEMU" >/dev/null 2>&1; then
  echo "Error: qemu-system-i386 not found. Install QEMU or set QEMU=/path/to/qemu-system-i386" >&2
  exit 1
fi
if [[ ! -f pm.img ]]; then
  echo "Error: pm.img not found in $(pwd)." >&2
  echo "Build Floppy OS from SOURCE first, then copy pm.img here." >&2
  exit 1
fi

# Create blank, sparse 64 MiB IDE disks only if missing.
# Existing images are NEVER overwritten.
for disk in disk_o.img disk_i.img; do
  if [[ ! -e "$disk" ]]; then
    truncate -s 64M "$disk"
    echo "Created blank virtual disk: $disk (64 MiB)"
  fi
done

args=(
  -drive "file=pm.img,format=raw,if=ide,index=0"
  -drive "file=disk_o.img,format=raw,if=ide,index=1"
  -drive "file=disk_i.img,format=raw,if=ide,index=2"
)
if [[ -f dos.img ]]; then
  args+=(-drive "file=dos.img,format=raw,if=ide,index=3")
fi

exec "$QEMU" "${args[@]}"
