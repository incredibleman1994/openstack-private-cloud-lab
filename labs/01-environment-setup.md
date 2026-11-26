# Lab 01: Environment setup (DevStack)

**Goal:** a working single-node OpenStack you can reach from the Horizon dashboard and the CLI.

## 1. Prepare the VM

Create a fresh Ubuntu 24.04 LTS VM (VirtualBox, VMware, KVM/libvirt, Proxmox or a cloud VM) with **8-16 GB RAM, 4 vCPUs, 60 GB disk**.

* Enable **nested virtualisation** if you can (VirtualBox: *Settings → System → Processor → Enable Nested VT-x/AMD-V*; KVM: `nested=1`). Without it OpenStack still works, but guests run under slow QEMU emulation.
* Use a **bridged** or **host-only** network adapter so your browser can reach Horizon. With NAT you must add a port forward (host `8080` → guest `80`).
* Create a normal user with `sudo`. DevStack refuses to run as root.

## 2. Install

```bash
git clone https://github.com/<your-username>/openstack-private-cloud-lab.git
cd openstack-private-cloud-lab
chmod +x devstack/install.sh scripts/*.sh
nano devstack/local.conf.example       # set ADMIN_PASSWORD
tmux new -s stack
./devstack/install.sh
```

What `install.sh` does: runs `scripts/prereq-check.sh`, creates the `stack` user, clones DevStack to `/opt/stack/devstack`, writes `local.conf` (auto-detecting `HOST_IP`, adding `LIBVIRT_TYPE=qemu` if `/dev/kvm` is absent) and runs `./stack.sh`.

The end of a successful run prints the Horizon URL and credentials. If `stack.sh` fails, read `/opt/stack/logs/stack.sh.log`; most failures are network/mirror timeouts: re-run `./stack.sh` as the `stack` user (`sudo -u stack -H bash -c 'cd /opt/stack/devstack && ./stack.sh'`).

> **Take a VM snapshot now.** It is the fastest recovery path.

## 3. Verify (CLI)

```bash
source /opt/stack/devstack/openrc admin admin
./scripts/health-check.sh            # or manually:
openstack service list
openstack compute service list       # nova-conductor, nova-scheduler, nova-compute: state "up"
openstack network agent list         # all Alive
openstack volume service list        # cinder-scheduler, cinder-volume: state "up"
openstack hypervisor list
openstack network list               # DevStack creates 'public', 'private', 'shared'
openstack image list                 # DevStack uploads a CirrOS image
```

## 4. Verify (Horizon)

1. Browse to `http://<HOST_IP>/dashboard`.
2. Log in: **Domain** `default`, **User** `admin`, **Password** = your `ADMIN_PASSWORD`.
3. **Admin → System → System Information** shows the service list and compute/network/volume services.
4. **Admin → Compute → Hypervisors** shows the single compute node and its vCPU/RAM/disk totals.

## 5. Where things live

| What | Where |
|------|-------|
| DevStack checkout | `/opt/stack/devstack` |
| Service code & data | `/opt/stack` |
| Service logs | systemd journal: `sudo journalctl -u devstack@<service>` |
| Install log | `/opt/stack/logs/stack.sh.log` |
| Horizon log | `/var/log/apache2/horizon_error.log` |
| Credentials | `/opt/stack/devstack/openrc`, `/etc/openstack/clouds.yaml` |

**Screenshots to capture:** Horizon login, System Information, Hypervisors, terminal with `openstack compute service list`.

Next: [Lab 02 - Keystone](02-keystone-identity.md)
