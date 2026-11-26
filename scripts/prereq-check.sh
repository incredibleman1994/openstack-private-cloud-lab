#!/usr/bin/env bash
# Pre-install checks for the DevStack host. Exits non-zero on any FAIL.
set -uo pipefail

fail=0
ok()   { printf '  [ OK ] %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }
bad()  { printf '  [FAIL] %s\n' "$*"; fail=1; }

echo "Pre-install checks"

# shellcheck disable=SC1091
. /etc/os-release
case "${ID}-${VERSION_ID}" in
  ubuntu-24.04|ubuntu-22.04) ok "OS: $PRETTY_NAME" ;;
  *) warn "OS is $PRETTY_NAME - this lab is written for Ubuntu 24.04 LTS" ;;
esac

if [[ $EUID -ne 0 ]]; then ok "Running as non-root user"; else bad "Do not run as root"; fi

mem_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
if   (( mem_mb < 7000 ));  then bad  "RAM ${mem_mb} MB - need at least 8 GB"
elif (( mem_mb < 15000 )); then warn "RAM ${mem_mb} MB - fine for CirrOS labs, use 16 GB for Ubuntu images"
else ok "RAM ${mem_mb} MB"; fi

cpus=$(nproc)
if   (( cpus < 2 )); then bad  "${cpus} vCPU - need at least 2 (4 recommended)"
elif (( cpus < 4 )); then warn "${cpus} vCPU - 4 recommended"
else ok "${cpus} vCPUs"; fi

disk_gb=$(df --output=avail -BG / | tail -n1 | tr -dc '0-9')
if   (( disk_gb < 40 )); then bad  "${disk_gb} GB free on / - need at least 40 GB (60 recommended)"
elif (( disk_gb < 60 )); then warn "${disk_gb} GB free on / - 60 GB recommended"
else ok "${disk_gb} GB free on /"; fi

if [[ -e /dev/kvm ]]; then ok "/dev/kvm present (hardware acceleration)"
else warn "/dev/kvm missing - instances will use slow QEMU emulation. Enable nested virtualisation if possible."; fi

if command -v curl >/dev/null; then
  if curl -fsS -m 10 -o /dev/null https://opendev.org; then ok "Can reach opendev.org"
  else bad "Cannot reach https://opendev.org (needed to clone OpenStack)"; fi
else
  warn "curl not installed - skipping connectivity check"
fi

exit $fail
