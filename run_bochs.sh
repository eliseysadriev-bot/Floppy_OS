#!/usr/bin/env bash
# Run Floppy OS in Bochs on Linux. Requires Bochs and its BIOS ROMs.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if ! command -v bochs >/dev/null 2>&1; then
  echo "Error: Bochs is not installed (bochs command not found)." >&2
  exit 1
fi
if [[ ! -f pm.img ]]; then
  echo "Error: pm.img not found. Build Floppy OS using build.sh first." >&2
  exit 1
fi
for disk in disk_o.img disk_i.img; do
  if [[ ! -e "$disk" ]]; then
    truncate -s 64M "$disk"
    echo "Created blank virtual disk: $disk"
  fi
done
find_rom() {
  local file="$1" path
  for path in "/usr/share/bochs/$file" "/usr/local/share/bochs/$file" "/usr/share/bochs/bios/$file"; do
    if [[ -f "$path" ]]; then printf '%s' "$path"; return 0; fi
  done
  return 1
}
bios="${BOCHS_BIOS:-$(find_rom BIOS-bochs-latest || true)}"
vga="${BOCHS_VGABIOS:-$(find_rom VGABIOS-lgpl-latest || true)}"
if [[ ! -f "$bios" || ! -f "$vga" ]]; then
  echo "Error: Bochs BIOS files not found. Set BOCHS_BIOS and BOCHS_VGABIOS to their paths." >&2
  exit 1
fi
# Generated separately: original Windows bochsrc.txt stays unchanged.
config="$(mktemp "${TMPDIR:-/tmp}/floppy-bochsrc.XXXXXX")"
trap 'rm -f "$config"' EXIT
cat > "$config" <<EOF
romimage: file="$bios"
vgaromimage: file="$vga"
megs: 64
ata0: enabled=1, ioaddr1=0x1f0, ioaddr2=0x3f0, irq=14
ata0-master: type=disk, path="$(pwd)/pm.img", mode=flat
ata0-slave: type=disk, path="$(pwd)/disk_o.img", mode=flat
ata1: enabled=1, ioaddr1=0x170, ioaddr2=0x370, irq=15
ata1-master: type=disk, path="$(pwd)/disk_i.img", mode=flat
boot: disk
mouse: enabled=1, toggle=ctrl+f10
log: "$(pwd)/bochsout.txt"
panic: action=ask
error: action=report
info: action=ignore
debug: action=ignore
EOF
bochs -q -f "$config"
