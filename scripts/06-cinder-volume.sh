#!/usr/bin/env bash
# Lab 06 - Cinder: persistent volume, attach, write data, snapshot, restore, verify
set -eo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
load_openrc; as_lab

FIP="$(get_fip "$VM1")"
[[ -n $FIP ]] || die "$VM1 has no floating IP - run 05-launch-instances.sh first."

log "Creating 1 GB volume $VOL1"
exists volume show "$VOL1" || openstack volume create --size 1 "$VOL1"
wait_for "volume $VOL1 available/in-use" 120 bash -c \
  "s=\$(openstack volume show '$VOL1' -f value -c status); [[ \$s == available || \$s == in-use ]]"

if volume_status_is "$VOL1" available; then
  log "Attaching $VOL1 to $VM1"
  openstack server add volume "$VM1" "$VOL1"
  wait_for "volume $VOL1 in-use" 60 volume_status_is "$VOL1" in-use
fi

log "Formatting and mounting inside the instance, writing a proof file"
ssh_vm "$FIP" 'cat /proc/partitions'
# shellcheck disable=SC2016  # runs on the remote host; nothing should expand locally
ssh_vm "$FIP" 'sudo mkfs.ext4 -q -F /dev/vdb && sudo mkdir -p /mnt/data && sudo mount /dev/vdb /mnt/data \
  && echo "written before the snapshot - $(date)" | sudo tee /mnt/data/proof.txt && sync'

log "Snapshot $SNAP1 (--force because the volume is in-use)"
exists volume snapshot show "$SNAP1" \
  || openstack volume snapshot create --volume "$VOL1" --force "$SNAP1"
wait_for "snapshot $SNAP1 available" 120 snapshot_status_is "$SNAP1" available

log "Overwrite the live data so we can prove the snapshot holds the old version"
ssh_vm "$FIP" 'echo "CHANGED AFTER SNAPSHOT" | sudo tee /mnt/data/proof.txt && sync'

log "Restore snapshot into a new volume $VOL_RESTORED"
exists volume show "$VOL_RESTORED" || openstack volume create --snapshot "$SNAP1" "$VOL_RESTORED"
wait_for "volume $VOL_RESTORED available" 120 volume_status_is "$VOL_RESTORED" available
openstack server add volume "$VM1" "$VOL_RESTORED"
wait_for "volume $VOL_RESTORED in-use" 60 volume_status_is "$VOL_RESTORED" in-use

log "Mount the restored volume and compare"
ssh_vm "$FIP" 'sudo mkdir -p /mnt/restored && sudo mount /dev/vdc /mnt/restored'
echo "  live volume     : $(ssh_vm "$FIP" 'cat /mnt/data/proof.txt')"
echo "  restored volume : $(ssh_vm "$FIP" 'cat /mnt/restored/proof.txt')"

log "Detaching restored volume"
ssh_vm "$FIP" 'sudo umount /mnt/restored'
openstack server remove volume "$VM1" "$VOL_RESTORED"

openstack volume list
openstack volume snapshot list
