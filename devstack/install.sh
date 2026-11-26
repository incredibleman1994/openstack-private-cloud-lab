#!/usr/bin/env bash
# Install a single-node DevStack on Ubuntu (24.04 LTS recommended).
#
#   ./devstack/install.sh [path/to/local.conf]
#
# Run as a normal user with sudo (NOT root). Takes 20-40 minutes, so run it
# inside tmux/screen. Override the release with:
#   DEVSTACK_BRANCH=stable/<release> ./devstack/install.sh
# Latest releases: https://releases.openstack.org
set -euo pipefail

DEVSTACK_BRANCH="${DEVSTACK_BRANCH:-stable/2025.2}"
STACK_USER="stack"
STACK_HOME="/opt/stack"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_SRC="${1:-$SCRIPT_DIR/local.conf.example}"

log() { printf '\n\033[1;34m[install]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Run as a normal user with sudo, not as root."
command -v sudo >/dev/null || die "sudo is required."
[[ -f $CONF_SRC ]] || die "Config file not found: $CONF_SRC"

log "Pre-flight checks"
bash "$SCRIPT_DIR/../scripts/prereq-check.sh"

log "Installing git"
sudo apt-get update -y
sudo apt-get install -y git

if ! id "$STACK_USER" &>/dev/null; then
  log "Creating the '$STACK_USER' user (DevStack refuses to run as root)"
  sudo useradd -s /bin/bash -d "$STACK_HOME" -m "$STACK_USER"
fi
sudo chmod +x "$STACK_HOME"
echo "$STACK_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack >/dev/null
sudo chmod 440 /etc/sudoers.d/stack

if [[ ! -d $STACK_HOME/devstack ]]; then
  log "Cloning DevStack ($DEVSTACK_BRANCH)"
  sudo -u "$STACK_USER" -H git clone https://opendev.org/openstack/devstack \
    -b "$DEVSTACK_BRANCH" "$STACK_HOME/devstack"
fi

HOST_IP="${HOST_IP:-$(ip -4 route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')}"
[[ -n $HOST_IP ]] || die "Could not detect HOST_IP. Run: HOST_IP=<ip> $0"

log "Writing local.conf (HOST_IP=$HOST_IP)"
LOCAL_CONF="$STACK_HOME/devstack/local.conf"
sed "s|__HOST_IP__|$HOST_IP|g" "$CONF_SRC" | sudo -u "$STACK_USER" tee "$LOCAL_CONF" >/dev/null

if [[ ! -e /dev/kvm ]] && ! grep -q '^LIBVIRT_TYPE' "$LOCAL_CONF"; then
  log "/dev/kvm not found - falling back to QEMU emulation (instances will be slow)"
  echo "LIBVIRT_TYPE=qemu" | sudo -u "$STACK_USER" tee -a "$LOCAL_CONF" >/dev/null
fi

log "Running stack.sh - log: $STACK_HOME/logs/stack.sh.log"
sudo -u "$STACK_USER" -H bash -c "cd $STACK_HOME/devstack && ./stack.sh"

log "Done."
echo "  Horizon : http://$HOST_IP/dashboard   (domain: default, user: admin)"
echo "  CLI     : source $STACK_HOME/devstack/openrc admin admin"
echo "  Next    : ./scripts/health-check.sh   then   ./scripts/run-all.sh"
