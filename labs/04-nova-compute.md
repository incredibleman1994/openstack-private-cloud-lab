# Lab 04: Nova - flavors and instances

**Goal:** define custom flavors, create an SSH keypair, launch instances and manage their lifecycle.

**Automated:** `./scripts/03-nova-flavors.sh` then `./scripts/05-launch-instances.sh` (the second needs the network from [Lab 05](05-neutron-networking.md): run `04-neutron-network.sh` first, or use `run-all.sh`).

## Flavors (admin)

A flavor is a hardware template: vCPUs, RAM, root disk.

```bash
source /opt/stack/devstack/openrc admin admin
openstack flavor create --vcpus 1 --ram 256  --disk 1  --public lab.nano
openstack flavor create --vcpus 1 --ram 1024 --disk 10 --public lab.small
openstack flavor create --vcpus 2 --ram 2048 --disk 20 --public lab.medium
openstack flavor list --sort-column RAM
openstack flavor show lab.small
```

A flavor's vCPU/RAM/disk values cannot be edited after creation: create a new flavor instead. Extra specs (`openstack flavor set --property key=value`) can still be added or changed to tune scheduling and CPU behaviour.

## Keypair (tenant)

```bash
source labuser-openrc.sh
ssh-keygen -t ed25519 -N "" -f ~/.ssh/lab-key
openstack keypair create --public-key ~/.ssh/lab-key.pub lab-key
```

## Launch

```bash
openstack server create \
  --flavor lab.nano --image cirros-0.6.2 \
  --network lab-net \
  --security-group lab-sg-ssh-icmp --security-group lab-sg-web \
  --key-name lab-key \
  --user-data config/user-data.sh \
  --wait lab-vm1

openstack server list
openstack server show lab-vm1
```

`--user-data` is a cloud-init script that runs on first boot (here it starts a tiny web server).

## Manage the lifecycle

```bash
openstack server stop lab-vm1 ; openstack server start lab-vm1
openstack server reboot --soft lab-vm1          # graceful (guest OS)
openstack server reboot --hard lab-vm1          # power-cycle
openstack server pause lab-vm1  ; openstack server unpause lab-vm1     # freeze in RAM
openstack server suspend lab-vm1 ; openstack server resume lab-vm1     # save RAM to disk
openstack console log show lab-vm1              # serial console output (boot + cloud-init)
openstack console url show lab-vm1              # browser VNC console URL
openstack server event list lab-vm1             # history of actions + request IDs
openstack limits show --absolute                # your usage vs quota
```

### Snapshot an instance into an image

```bash
openstack server image create --name lab-vm1-snap lab-vm1
openstack image list                            # new image appears in Glance
openstack server create --flavor lab.nano --image lab-vm1-snap --network lab-net lab-vm1-clone --wait
```

Note the difference: an **instance snapshot** (Nova → Glance) captures the root disk; a **volume snapshot** (Cinder, [Lab 06](06-cinder-storage.md)) captures a block volume.

### Delete

```bash
openstack server delete lab-vm1-clone
```

## Horizon

* **Admin → Compute → Flavors → Create Flavor** (name, vCPUs, RAM, root disk).
* **Project → Compute → Key Pairs → Create/Import Key Pair.**
* **Project → Compute → Instances → Launch Instance**. The wizard steps are: Details → Source (image, *Create New Volume: No*) → Flavor → Networks → Security Groups → Key Pair → Configuration (paste user-data).
* Row dropdown ▸ **Console**, **Create Snapshot**, **Soft Reboot**, **Shut Off Instance**, **Associate Floating IP**, **Attach Volume**, **View Log**.
* **Project → Compute → Overview** gives donut charts of quota usage.

**Screenshots:** flavor list, launch wizard, instance list with ACTIVE state, console, instance detail → Log tab.

Next: [Lab 05 - Neutron](05-neutron-networking.md)
