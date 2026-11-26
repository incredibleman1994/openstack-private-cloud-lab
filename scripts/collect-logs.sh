#!/usr/bin/env bash
# Gather everything useful for a bug report or a post-mortem into ./logs/collected-<timestamp>/
#   SINCE="30 min ago" ./collect-logs.sh
set -eo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
load_openrc; as_admin

SINCE="${SINCE:-1 hour ago}"
OUT="$LAB_ROOT/logs/collected-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

run() { local name="$1"; shift; "$@" >"$OUT/$name.txt" 2>&1 || true; }

log "Service state"
run services          openstack service list
run compute-services  openstack compute service list
run hypervisors       openstack hypervisor list --long
run network-agents    openstack network agent list
run volume-services   openstack volume service list
run servers           openstack server list --all-projects --long
run volumes           openstack volume list --all-projects
run networks          openstack network list
run limits            openstack quota show "$LAB_PROJECT"

log "Details of every ERROR instance"
for id in $(openstack server list --all-projects --status ERROR -f value -c ID); do
  run "server-$id"        openstack server show "$id"
  run "server-$id-events" openstack server event list "$id"
done

log "Per-service journals (since: $SINCE)"
for svc in keystone g-api placement-api n-api n-sch n-cond-cell1 n-cpu q-svc c-api c-sch c-vol; do
  # shellcheck disable=SC2024  # sudo only reads; $OUT is user-owned
  sudo journalctl -u "devstack@$svc" --since "$SINCE" --no-pager >"$OUT/journal-$svc.log" 2>&1 || true
done
# shellcheck disable=SC2024
sudo tail -n 300 /var/log/apache2/horizon_error.log >"$OUT/horizon_error.log" 2>&1 || true
# shellcheck disable=SC2024
sudo tail -n 200 /opt/stack/logs/stack.sh.log >"$OUT/stack.sh.tail.log" 2>&1 || true
systemctl list-units 'devstack@*' --all --no-pager >"$OUT/devstack-units.txt" 2>&1 || true

log "Error summary"
grep -hE ' ERROR | CRITICAL |Traceback' "$OUT"/journal-*.log 2>/dev/null | tail -n 60 >"$OUT/errors-summary.txt" || true
echo "Collected into: $OUT"
echo "Review first:   $OUT/errors-summary.txt"
