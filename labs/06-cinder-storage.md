# Lab 06: Cinder - persistent block storage and snapshots

**Goal:** create a volume, attach it to an instance, store data on it, snapshot it, and restore the snapshot into a new volume.

**Automated:** `./scripts/06-cinder-volume.sh` (requires `lab-vm1` from Lab 05 with a floating IP)

> An instance's root disk is **ephemeral**: deleting the instance deletes it. A Cinder volume lives independently and survives instance deletion.

## CLI

```bash
source labuser-openrc.sh

openstack volume type list                       # DevStack: lvmdriver-1
openstack volume create --size 1 lab-vol1
openstack volume list                            # status: available

openstack server add volume lab-vm1 lab-vol1     # status becomes in-use
openstack volume show lab-vol1 -c status -c attachments
```

### Use it inside the guest

```bash
ssh -i ~/.ssh/lab-key cirros@<floating-ip>
$ cat /proc/partitions                           # vda = root disk, vdb = new volume
$ sudo mkfs.ext4 /dev/vdb
$ sudo mkdir /mnt/data && sudo mount /dev/vdb /mnt/data
$ echo "hello from cinder" | sudo tee /mnt/data/proof.txt && sync
```

### Snapshot and restore

```bash
openstack volume snapshot create --volume lab-vol1 --force lab-vol1-snap1   # --force: volume is in-use
openstack volume snapshot list

openstack volume create --snapshot lab-vol1-snap1 lab-vol1-restored
openstack server add volume lab-vm1 lab-vol1-restored
# in the guest:
$ sudo mkdir /mnt/restored && sudo mount /dev/vdc /mnt/restored && cat /mnt/restored/proof.txt
```

The script goes one step further: it **overwrites** the live file after taking the snapshot, then shows that the restored volume still holds the original contents, which is the whole point of a snapshot.

### Prove persistence beyond the instance

```bash
# unmount in the guest first: sudo umount /mnt/data
openstack server remove volume lab-vm1 lab-vol1
openstack server delete lab-vm1 --wait
openstack volume list                            # lab-vol1 still exists, status available
# launch a new instance, attach lab-vol1, mount it (do NOT mkfs again) -> proof.txt is still there
```

### Stretch goals

```bash
# Extend a detached volume
openstack volume set --size 2 lab-vol1

# Boot from volume: root disk is a Cinder volume, so it survives instance deletion
openstack server create --flavor lab.small --image cirros-0.6.2 \
  --boot-from-volume 2 --network lab-net --key-name lab-key bfv-vm --wait

# Clean up
openstack volume snapshot delete lab-vol1-snap1
openstack volume delete lab-vol1-restored
```

## Horizon

* **Project → Volumes → Volumes → Create Volume** (source: *No source, empty volume*).
* Row dropdown ▸ **Manage Attachments** to attach to / detach from an instance.
* Row dropdown ▸ **Create Snapshot**. Then **Project → Volumes → Snapshots → Create Volume** restores it.
* **Admin → Volume → Volumes** shows which host/backend holds each volume.

**Screenshots:** volume list with *in-use* status, snapshot list, terminal showing `proof.txt` from restored volume.

Next: [Lab 07 - Troubleshooting](07-troubleshooting.md)
