#!/usr/bin/env bash
# Lab 04 (part 1) - Nova: custom flavors (admin) and an SSH keypair (lab user)
set -eo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
load_openrc; as_admin

create_flavor() { # create_flavor <name> <vcpus> <ram_mb> <disk_gb>
  exists flavor show "$1" || openstack flavor create --vcpus "$2" --ram "$3" --disk "$4" --public "$1"
}
log "Custom flavors"
create_flavor "$FLAVOR_NANO"   1  256  1
create_flavor "$FLAVOR_SMALL"  1 1024 10
create_flavor "$FLAVOR_MEDIUM" 2 2048 20
openstack flavor list --sort-column RAM

as_lab
log "SSH keypair '$LAB_KEYPAIR' (private key: $SSH_KEY)"
mkdir -p "$(dirname "$SSH_KEY")"
[[ -f $SSH_KEY ]] || ssh-keygen -q -t ed25519 -N "" -C "$LAB_KEYPAIR" -f "$SSH_KEY"
exists keypair show "$LAB_KEYPAIR" || openstack keypair create --public-key "$SSH_KEY.pub" "$LAB_KEYPAIR"
openstack keypair list
