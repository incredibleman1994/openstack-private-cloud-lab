#!/usr/bin/env bash
# Lab 03 - Glance: download and register images
#   WITH_UBUNTU=1 ./02-glance-images.sh   also registers an Ubuntu 24.04 cloud image (~600 MB)
set -eo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
load_openrc; as_admin

DL="$LAB_ROOT/downloads"; mkdir -p "$DL"

fetch() { # fetch <url> <dest>
  [[ -f $2 ]] && return 0
  log "Downloading $(basename "$2")"
  curl -fL --retry 3 -o "$2.part" "$1" && mv "$2.part" "$2"
}

CIRROS_FILE="$DL/cirros-${CIRROS_VERSION}-x86_64-disk.img"
fetch "https://download.cirros-cloud.net/${CIRROS_VERSION}/cirros-${CIRROS_VERSION}-x86_64-disk.img" "$CIRROS_FILE"

log "Registering $CIRROS_IMAGE"
exists image show "$CIRROS_IMAGE" || openstack image create \
  --file "$CIRROS_FILE" --disk-format qcow2 --container-format bare \
  --public --min-disk 1 --property os_distro=cirros --tag lab "$CIRROS_IMAGE"

if [[ "${WITH_UBUNTU:-0}" == "1" ]]; then
  UBUNTU_FILE="$DL/noble-server-cloudimg-amd64.img"
  fetch "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img" "$UBUNTU_FILE"
  log "Registering $UBUNTU_IMAGE"
  exists image show "$UBUNTU_IMAGE" || openstack image create \
    --file "$UBUNTU_FILE" --disk-format qcow2 --container-format bare \
    --public --min-disk 5 --min-ram 1024 --property os_distro=ubuntu --tag lab "$UBUNTU_IMAGE"
fi

log "Images"
openstack image list
openstack image show "$CIRROS_IMAGE" -c name -c status -c size -c disk_format -c min_disk -c visibility -c tags
