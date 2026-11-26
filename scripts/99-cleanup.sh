#!/usr/bin/env bash
# Tear down everything the lab created (reverse dependency order).
#   ./99-cleanup.sh          asks for confirmation
#   ./99-cleanup.sh --yes    no prompt
# Glance images and your local ~/.ssh key are kept.
set -eo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
load_openrc

if [[ "${1:-}" != "--yes" ]]; then
  read -rp "Delete ALL resources in project '$LAB_PROJECT', its users and the lab flavors? [y/N] " a
  [[ $a == [yY] ]] || { echo "Aborted."; exit 0; }
fi

as_lab
log "Servers"
for s in $(openstack server list -f value -c ID); do openstack server delete --wait "$s" || true; done

log "Floating IPs"
for f in $(openstack floating ip list -f value -c ID); do openstack floating ip delete "$f" || true; done

log "Volume snapshots"
for s in $(openstack volume snapshot list -f value -c ID); do openstack volume snapshot delete "$s" || true; done
for _ in $(seq 60); do   # wait up to ~3 min; never abort the cleanup
  [[ -z "$(openstack volume snapshot list -f value -c ID)" ]] && break
  sleep 3
done

log "Volumes"
for v in $(openstack volume list -f value -c ID); do openstack volume delete --force "$v" || true; done
for _ in $(seq 60); do
  [[ -z "$(openstack volume list -f value -c ID)" ]] && break
  sleep 3
done

log "Router, subnets, networks"
if exists router show "$LAB_ROUTER"; then
  openstack router unset --external-gateway "$LAB_ROUTER" || true
  openstack router remove subnet "$LAB_ROUTER" "$LAB_SUBNET" || true
  openstack router delete "$LAB_ROUTER" || true
fi
for n in "$LAB_NET" "$ISO_NET" demo-nodhcp-net; do
  for sub in $(openstack subnet list --network "$n" -f value -c ID 2>/dev/null); do
    openstack subnet delete "$sub" || true
  done
  exists network show "$n" && openstack network delete "$n" || true
done

log "Security groups and keypair"
for sg in "$SG_SSH" "$SG_WEB"; do exists security group show "$sg" && openstack security group delete "$sg" || true; done
exists keypair show "$LAB_KEYPAIR" && openstack keypair delete "$LAB_KEYPAIR" || true

as_admin
log "Flavors"
for f in "$FLAVOR_NANO" "$FLAVOR_SMALL" "$FLAVOR_MEDIUM" lab.huge-disk; do
  exists flavor show "$f" && openstack flavor delete "$f" || true
done

log "Users and project"
for u in "$LAB_USER" "$LAB_READER"; do exists user show --domain default "$u" && openstack user delete --domain default "$u" || true; done
exists project show "$LAB_PROJECT" && openstack project delete "$LAB_PROJECT" || true
rm -f "$LAB_ROOT/labuser-openrc.sh" "$LAB_ROOT/labreader-openrc.sh"

log "Cleanup complete."
