# Lab 03: Glance - images

**Goal:** upload and manage the images instances boot from.

**Automated:** `./scripts/02-glance-images.sh` (add `WITH_UBUNTU=1` for an Ubuntu 24.04 cloud image, ~600 MB)

## CLI

```bash
source /opt/stack/devstack/openrc admin admin

# 1. Download a tiny test image (CirrOS, ~20 MB)
curl -fLO https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img

# 2. Upload it
openstack image create \
  --file cirros-0.6.2-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --public --min-disk 1 --tag lab cirros-0.6.2

# 3. Inspect
openstack image list
openstack image show cirros-0.6.2 -c name -c status -c size -c min_disk -c visibility -c tags
```

### Manage metadata and visibility

```bash
openstack image set --property os_distro=cirros cirros-0.6.2
openstack image set --min-ram 128 cirros-0.6.2
openstack image set --private cirros-0.6.2                       # hide from other projects
openstack image set --shared  cirros-0.6.2
openstack image add project cirros-0.6.2 lab-project             # share with a specific project
openstack image set --public  cirros-0.6.2
```

### Lifecycle

```bash
openstack image set --deactivate cirros-0.6.2      # nobody can boot from it
openstack server create ... --image cirros-0.6.2   # fails while deactivated
openstack image set --activate cirros-0.6.2
openstack image save --file /tmp/backup.img cirros-0.6.2   # download it back
openstack image delete old-image
```

### Ubuntu cloud image (optional)

```bash
curl -fLO https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
openstack image create --file noble-server-cloudimg-amd64.img \
  --disk-format qcow2 --container-format bare --public \
  --min-disk 5 --min-ram 1024 ubuntu-24.04
```
Default login user for Ubuntu cloud images is `ubuntu`; for CirrOS it is `cirros`. Ubuntu needs a flavor with at least 5 GB disk and ~1 GB RAM (`lab.small`).

> **Why `qcow2` + `bare`?** `disk-format` is how the bytes are laid out on disk (qcow2 = copy-on-write, compressed, sparse); `container-format bare` means there is no wrapper such as OVF.

## Horizon

* **Project → Compute → Images → Create Image**: choose *File* as source, pick the `.img`, format **QCOW2**, set min disk/RAM, visibility.
* Click an image name to edit metadata, or use the row dropdown for *Launch*, *Update Metadata*, *Create Volume*.
* **Admin → Compute → Images** shows all images across projects (admin only).

**Screenshots:** image list showing both images, image detail page with properties.

Next: [Lab 04 - Nova](04-nova-compute.md)
