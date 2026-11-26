#!/usr/bin/env bash
#
# Read-only hardware audit for Proxmox Wi-Fi Edition.
# Intended to run on the target Mac mini from a Linux live environment or
# installed Linux system. It does not install packages, load modules, change
# networking, or expose Wi-Fi credentials.
#
# Usage:
#   bash scripts/detect-macmini-hardware.sh
#   bash scripts/detect-macmini-hardware.sh --output hardware-report.txt
#
set -Eeuo pipefail
umask 077

OUTPUT=""
while (($#)); do
  case "$1" in
    --output|-o)
      if (($# < 2)); then
        printf 'Error: %s requires a file path.\n' "$1" >&2
        exit 2
      fi
      OUTPUT=$2
      shift 2
      ;;
    --help|-h)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      printf 'Run with --help for usage.\n' >&2
      exit 2
      ;;
  esac
done

if [[ -n "$OUTPUT" ]]; then
  # Avoid silently overwriting an existing report.
  if [[ -e "$OUTPUT" ]]; then
    printf 'Error: output file already exists: %s\n' "$OUTPUT" >&2
    exit 1
  fi
  if ! ( : > "$OUTPUT" ) 2>/dev/null; then
    printf 'Error: cannot write output file: %s\n' "$OUTPUT" >&2
    exit 1
  fi
  chmod 600 "$OUTPUT"
  exec > >(tee "$OUTPUT")
fi

have() { command -v "$1" >/dev/null 2>&1; }

section() {
  printf '\n\n===== %s =====\n' "$1"
}

show_file() {
  local label=$1 path=$2
  printf '\n-- %s --\n' "$label"
  if [[ -r "$path" ]]; then
    tr '\0' '\n' < "$path" 2>/dev/null | sed '/^[[:space:]]*$/d' || true
  else
    printf 'Not available (%s)\n' "$path"
  fi
}

section "Report metadata"
printf 'Generated (UTC): '
date -u '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || printf 'unknown\n'
printf 'Script version: 1.0.0\n'
printf 'User: %s\n' "$(id -un 2>/dev/null || printf unknown)"
printf 'Kernel: %s\n' "$(uname -srmo 2>/dev/null || printf unknown)"

section "System identity"
for f in /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name \
         /sys/class/dmi/id/product_version /sys/class/dmi/id/board_name \
         /sys/class/dmi/id/bios_version; do
  show_file "$(basename "$f")" "$f"
done
if have hostnamectl; then
  printf '\n-- hostnamectl (static hardware/OS fields) --\n'
  hostnamectl 2>/dev/null | sed -n -E '/^(Static hostname|Icon name|Chassis|Virtualization|Operating System|Kernel|Architecture):/p' || true
fi

section "Operating system"
if [[ -r /etc/os-release ]]; then
  # Only print non-secret OS identification fields.
  grep -E '^(NAME|VERSION|VERSION_ID|ID|ID_LIKE|PRETTY_NAME)=' /etc/os-release || true
else
  printf '/etc/os-release not present.\n'
fi

section "PCI devices"
if have lspci; then
  lspci -nnk 2>&1 || true
else
  printf 'lspci not installed. Install pciutils if a detailed PCI inventory is needed.\n'
fi

section "USB devices"
if have lsusb; then
  lsusb 2>&1 || true
else
  printf 'lsusb not installed. Install usbutils if a detailed USB inventory is needed.\n'
fi

section "Network interfaces"
if have ip; then
  ip -brief link 2>&1 || true
  printf '\n-- Address summary (IP addresses only; no routes or DNS) --\n'
  ip -brief address 2>&1 || true
else
  printf 'ip command not installed.\n'
fi

section "Wireless interfaces"
found_wireless=0
for path in /sys/class/net/*; do
  [[ -e "$path" ]] || continue
  iface=$(basename "$path")
  if [[ -d "$path/wireless" || -e "$path/phy80211" ]]; then
    found_wireless=1
    printf '\n-- %s --\n' "$iface"
    if have iw; then
      iw dev "$iface" info 2>&1 || true
    else
      printf 'iw not installed; wireless interface detected via sysfs.\n'
    fi
    if [[ -L "$path/device/driver" ]]; then
      printf 'Driver: %s\n' "$(basename "$(readlink -f "$path/device/driver")")"
    fi
    if [[ -r "$path/address" ]]; then
      printf 'MAC address: %s\n' "$(cat "$path/address")"
    fi
  fi
done
if ((found_wireless == 0)); then
  printf 'No wireless interface currently exposed in /sys/class/net.\n'
  printf 'This may mean the driver is unavailable; inspect PCI devices above.\n'
fi

section "Radio block status"
if have rfkill; then
  rfkill list 2>&1 || true
else
  printf 'rfkill not installed.\n'
fi

section "Loaded driver modules"
if have lsmod; then
  lsmod | awk 'NR == 1 || tolower($1) ~ /(wl|brcm|b43|bcma|ssb|cfg80211|mac80211)/' || true
else
  printf 'lsmod not available.\n'
fi

section "Relevant kernel messages"
if have journalctl; then
  journalctl -k -b --no-pager 2>/dev/null |
    grep -Ei '(brcm|broadcom|bcma|b43|wl:|firmware|wlan|wifi|80211)' |
    tail -n 100 || true
elif have dmesg; then
  dmesg 2>/dev/null |
    grep -Ei '(brcm|broadcom|bcma|b43|wl:|firmware|wlan|wifi|80211)' |
    tail -n 100 || true
else
  printf 'Neither journalctl nor dmesg is available.\n'
fi

section "Relevant installed packages"
if have dpkg-query; then
  dpkg-query -W -f='${binary:Package}\t${Version}\n' 2>/dev/null |
    grep -Ei '(broadcom|bcmwl|firmware|linux-image|proxmox|wireless-tools|wpasupplicant|iw)' ||
    printf 'No matching packages found (or package database unavailable).\n'
else
  printf 'dpkg-query not available; this may not be a Debian-family system.\n'
fi

section "Audit notes"
cat <<'NOTES'
- This report is intended for hardware compatibility analysis.
- It does not display saved Wi-Fi network names, passwords, PSKs, or private keys.
- PCI vendor/device IDs from lspci -nn are especially useful for identifying
  the Broadcom wireless chipset precisely.
- A missing wireless interface does not prove the hardware is absent; the
  required driver or firmware may not be loaded.
- Review the report before sharing it publicly. It can contain hardware
  identifiers, interface MAC addresses, IP addresses, and kernel log details.
NOTES

printf '\nAudit complete. No system settings were changed.\n'
