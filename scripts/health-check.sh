#!/usr/bin/env bash
# Post-install health check: are all OpenStack services up?
set -eo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
load_openrc; as_admin

log "Identity: token + service catalog"
openstack token issue -c expires -c project_id
openstack service list

log "Nova compute services"
openstack compute service list

log "Hypervisors"
openstack hypervisor list

log "Neutron agents"
openstack network agent list

log "Cinder services"
openstack volume service list

log "Networks / images / flavors present"
openstack network list
openstack image list
openstack flavor list

log "systemd units"
if systemctl --failed --no-legend --no-pager 'devstack@*' | grep -q .; then
  warn "Failed DevStack units:"
  systemctl --failed --no-pager 'devstack@*'
else
  echo "No failed devstack@* units."
fi
