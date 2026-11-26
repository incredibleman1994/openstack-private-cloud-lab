#!/usr/bin/env bash
# Lab 05 (part 1) - Neutron: networks, subnets, router, security groups
set -eo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
load_openrc; as_lab

log "Routed network: $LAB_NET ($LAB_SUBNET_CIDR)"
exists network show "$LAB_NET" || openstack network create "$LAB_NET"
exists subnet show "$LAB_SUBNET" || openstack subnet create --network "$LAB_NET" \
  --subnet-range "$LAB_SUBNET_CIDR" --dns-nameserver 8.8.8.8 "$LAB_SUBNET"

log "Isolated network (no router): $ISO_NET ($ISO_SUBNET_CIDR)"
exists network show "$ISO_NET" || openstack network create "$ISO_NET"
exists subnet show "$ISO_SUBNET" || openstack subnet create --network "$ISO_NET" \
  --subnet-range "$ISO_SUBNET_CIDR" "$ISO_SUBNET"

log "Router $LAB_ROUTER: gateway on '$EXTERNAL_NET', interface on $LAB_SUBNET"
exists router show "$LAB_ROUTER" || openstack router create "$LAB_ROUTER"
openstack router set "$LAB_ROUTER" --external-gateway "$EXTERNAL_NET"
openstack router add subnet "$LAB_ROUTER" "$LAB_SUBNET" 2>/dev/null \
  || warn "Subnet already attached to $LAB_ROUTER (ok on re-run)"

log "Security group $SG_SSH (ICMP + SSH)"
if ! exists security group show "$SG_SSH"; then
  openstack security group create --description "Allow ICMP and SSH in" "$SG_SSH"
  openstack security group rule create --ingress --protocol icmp "$SG_SSH"
  openstack security group rule create --ingress --protocol tcp --dst-port 22 "$SG_SSH"
fi

log "Security group $SG_WEB (HTTP + HTTPS)"
if ! exists security group show "$SG_WEB"; then
  openstack security group create --description "Allow HTTP and HTTPS in" "$SG_WEB"
  openstack security group rule create --ingress --protocol tcp --dst-port 80  "$SG_WEB"
  openstack security group rule create --ingress --protocol tcp --dst-port 443 "$SG_WEB"
fi

log "Result"
openstack network list
openstack router show "$LAB_ROUTER" -c name -c status -c external_gateway_info -c interfaces_info
openstack security group rule list "$SG_SSH"
