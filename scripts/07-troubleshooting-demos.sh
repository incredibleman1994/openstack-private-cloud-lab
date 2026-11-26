#!/usr/bin/env bash
# Lab 07 - deliberately break things, then practise diagnosing them.
#
#   ./07-troubleshooting-demos.sh <scenario>
#
#   no-valid-host   flavor demands more disk than the host has  -> instance ERROR
#   quota           exceed the project's instance quota         -> API 403
#   small-disk      image min-disk larger than flavor disk      -> API 400
#   no-dhcp         subnet without DHCP                         -> instance has no IP
#   cinder-down     stop cinder-volume, then create a volume   -> volume stuck
#   cleanup         remove everything these scenarios created
#
# Prerequisite: labs 02-05 completed (needs the lab network, image, flavors).
set -eo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
load_openrc

HUGE_FLAVOR="lab.huge-disk"
DEMO_NET="demo-nodhcp-net"
DEMO_SUBNET="demo-nodhcp-subnet"

scenario_no_valid_host() {
  as_admin
  exists flavor show "$HUGE_FLAVOR" \
    || openstack flavor create --vcpus 1 --ram 128 --disk 100000 --public "$HUGE_FLAVOR"
  as_lab
  log "Launching with a 100 TB root disk - this should end in ERROR"
  openstack server create --flavor "$HUGE_FLAVOR" --image "$CIRROS_IMAGE" \
    --network "$LAB_NET" --wait demo-novalid || true
  echo; openstack server show demo-novalid -c status -c fault
  echo; openstack server event list demo-novalid
  cat <<'EOF'

How to diagnose (as admin):
  1. The member-visible fault is deliberately generic ("No valid host was found").
  2. Read the scheduler log for the real reason:
       sudo journalctl -u devstack@n-sch --since "10 min ago" --no-pager \
         | grep -iE "no valid host|allocation candidates"
  3. Compare the flavor request with what the hypervisor offers:
       openstack flavor show lab.huge-disk -c disk
       openstack hypervisor list --long
  Fix: use a flavor that fits the host (e.g. lab.nano).
EOF
}

scenario_quota() {
  as_lab
  local used; used="$(openstack server list -f value -c ID | wc -l)"
  as_admin; openstack quota set --instances "$used" "$LAB_PROJECT"
  as_lab
  log "Quota is now $used instances and $used are in use - one more must be refused"
  openstack server create --flavor "$FLAVOR_NANO" --image "$CIRROS_IMAGE" \
    --network "$LAB_NET" demo-quota || true
  echo; openstack limits show --absolute | grep -iE 'instances|cores|ram' || true
  as_admin; openstack quota set --instances 6 "$LAB_PROJECT"
  log "Quota restored to 6. Diagnosis: 'openstack limits show --absolute' (member) or 'openstack quota show $LAB_PROJECT' (admin)."
}

scenario_small_disk() {
  as_admin; openstack image set --min-disk 20 "$CIRROS_IMAGE"
  trap 'as_admin; openstack image set --min-disk 1 "$CIRROS_IMAGE"' EXIT
  as_lab
  log "Image min-disk is 20 GB, flavor $FLAVOR_NANO has a 1 GB disk - the API should refuse"
  openstack server create --flavor "$FLAVOR_NANO" --image "$CIRROS_IMAGE" \
    --network "$LAB_NET" demo-smalldisk || true
  log "Diagnosis: compare 'openstack image show $CIRROS_IMAGE -c min_disk' with 'openstack flavor show $FLAVOR_NANO -c disk'. (min-disk restored on exit)"
}

scenario_no_dhcp() {
  as_lab
  exists network show "$DEMO_NET" || openstack network create "$DEMO_NET"
  exists subnet show "$DEMO_SUBNET" || openstack subnet create --network "$DEMO_NET" \
    --subnet-range 192.168.30.0/24 --no-dhcp "$DEMO_SUBNET"
  log "Launching on a subnet with DHCP disabled - status will be ACTIVE but the guest gets no IP"
  openstack server create --flavor "$FLAVOR_NANO" --image "$CIRROS_IMAGE" \
    --network "$DEMO_NET" --wait demo-nodhcp
  log "Waiting 60 s for the guest to finish booting..."; sleep 60
  openstack console log show demo-nodhcp | tail -n 25
  cat <<'EOF'

Diagnosis: status ACTIVE only means libvirt started the VM. The console log
shows DHCP discover messages with no lease and metadata requests failing.
  openstack subnet show demo-nodhcp-subnet -c enable_dhcp
Fix: openstack subnet set --dhcp demo-nodhcp-subnet, then reboot the instance.
EOF
}

scenario_cinder_down() {
  as_admin
  trap 'sudo systemctl start devstack@c-vol || true' EXIT
  log "Stopping cinder-volume"
  sudo systemctl stop devstack@c-vol
  as_lab
  openstack volume create --size 1 demo-vol-stuck
  log "Waiting 75 s so the service is reported down..."; sleep 75
  openstack volume show demo-vol-stuck -c status
  as_admin; openstack volume service list
  cat <<'EOF'

Diagnosis: 'openstack volume service list' shows cinder-volume as "down", and
the volume never leaves "creating" (or goes to "error" if the scheduler gives up).
  sudo systemctl status devstack@c-vol
  sudo journalctl -u devstack@c-sch -u devstack@c-vol --since "5 min ago" --no-pager
The script now restarts cinder-volume; run 'cleanup' afterwards.
EOF
}

scenario_cleanup() {
  as_lab
  for s in demo-novalid demo-quota demo-smalldisk demo-nodhcp; do
    exists server show "$s" && openstack server delete --wait "$s" || true
  done
  exists volume show demo-vol-stuck && openstack volume delete --force demo-vol-stuck || true
  exists subnet show "$DEMO_SUBNET"  && openstack subnet delete "$DEMO_SUBNET" || true
  exists network show "$DEMO_NET"    && openstack network delete "$DEMO_NET" || true
  as_admin
  exists flavor show "$HUGE_FLAVOR" && openstack flavor delete "$HUGE_FLAVOR" || true
  log "Demo resources removed."
}

case "${1:-}" in
  no-valid-host) scenario_no_valid_host ;;
  quota)         scenario_quota ;;
  small-disk)    scenario_small_disk ;;
  no-dhcp)       scenario_no_dhcp ;;
  cinder-down)   scenario_cinder_down ;;
  cleanup)       scenario_cleanup ;;
  *) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
