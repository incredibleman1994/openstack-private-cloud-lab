#!/usr/bin/env bash
# Lab 04 (part 2) / Lab 05 (part 2) - launch instances, attach a floating IP,
# prove connectivity and network isolation.
set -eo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
load_openrc; as_lab

log "Launching $VM1 on $LAB_NET (flavor $FLAVOR_NANO, image $CIRROS_IMAGE)"
exists server show "$VM1" || openstack server create \
  --flavor "$FLAVOR_NANO" --image "$CIRROS_IMAGE" --network "$LAB_NET" \
  --security-group "$SG_SSH" --security-group "$SG_WEB" \
  --key-name "$LAB_KEYPAIR" --user-data "$LAB_ROOT/config/user-data.sh" \
  --wait "$VM1"

log "Launching $VM_ISO on $ISO_NET (no router, no floating IP)"
exists server show "$VM_ISO" || openstack server create \
  --flavor "$FLAVOR_NANO" --image "$CIRROS_IMAGE" --network "$ISO_NET" \
  --security-group "$SG_SSH" --key-name "$LAB_KEYPAIR" --wait "$VM_ISO"

FIP="$(get_fip "$VM1")"
if [[ -z $FIP ]]; then
  log "Allocating a floating IP from '$EXTERNAL_NET'"
  FIP="$(openstack floating ip create "$EXTERNAL_NET" -f value -c floating_ip_address)"
  openstack server add floating ip "$VM1" "$FIP"
fi
log "$VM1 floating IP: $FIP"

log "Waiting for $FIP to answer ping (boot can take a minute)"
wait_for "ping $FIP" 180 ping -c1 -W2 "$FIP"

log "SSH into $VM1"
wait_for "ssh to $FIP" 120 ssh_vm "$FIP" true
ssh_vm "$FIP" 'hostname; ip -4 addr show eth0 | grep inet'

log "HTTP check (user-data web server)"
curl -s -m 5 "http://$FIP/" || warn "No HTTP answer yet - user-data may still be running"

log "Isolation test: $VM1 -> $VM_ISO must FAIL (different network, no router between them)"
ISO_IP="$(server_ip "$VM_ISO")"
if ssh_vm "$FIP" "ping -c 2 -W 2 $ISO_IP" >/dev/null 2>&1; then
  warn "Unexpected: $ISO_IP is reachable from $VM1"
else
  echo "    OK - $ISO_IP unreachable from $VM1, networks are isolated"
fi

openstack server list
