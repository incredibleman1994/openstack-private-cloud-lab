# Lab 07: Troubleshooting failed instance launches

**Goal:** build a repeatable method for diagnosing failures, then practise it on failures you cause on purpose.

**Automated:** `./scripts/07-troubleshooting-demos.sh <scenario>` and `./scripts/collect-logs.sh`

## The method

Work from the user-visible symptom down to the log that explains it.

1. **What state is it in, and why (as the tenant)?**
   ```bash
   openstack server show <vm> -c status -c fault
   openstack server event list <vm>          # note the Request ID (req-...)
   ```
   Tenants see a deliberately generic fault. Admins see more.
2. **Are the services healthy? (admin)**
   ```bash
   openstack compute service list        # state must be "up"
   openstack network agent list          # Alive
   openstack volume service list         # state "up"
   systemctl --failed 'devstack@*'
   ```
3. **Read the right service log.** DevStack runs each service as a systemd unit; logs are in the journal.
   ```bash
   sudo journalctl -u devstack@n-sch  --since "10 min ago" --no-pager      # scheduling decisions
   sudo journalctl -u devstack@n-cpu  --since "10 min ago" --no-pager      # building the VM
   sudo journalctl -u devstack@q-svc  --since "10 min ago" --no-pager      # networking
   sudo journalctl -u devstack@c-vol  --since "10 min ago" --no-pager      # volumes
   ```
4. **Follow one request across all services** using the request ID from step 1:
   ```bash
   sudo journalctl -u 'devstack@*' --no-pager | grep req-<id>
   ```
5. **If the VM is ACTIVE but unreachable**, ask the guest:
   ```bash
   openstack console log show <vm>        # did it get an IP? did cloud-init reach the metadata service?
   ```
6. **Hypervisor level:** `sudo ls /var/log/libvirt/qemu/` and `sudo tail /var/log/libvirt/qemu/instance-*.log`.
7. **Bundle everything** for later analysis: `./scripts/collect-logs.sh`.

Quick map from symptom to log:

| Symptom | First place to look |
|---------|--------------------|
| HTTP 401 / 403 | role assignments, `devstack@keystone` |
| Rejected immediately (quota, flavor/image) | `openstack limits show --absolute`, flavor + image properties |
| `ERROR` + "No valid host was found" | `devstack@n-sch`, `devstack@placement-api` |
| `ERROR` + build/spawn failure | `devstack@n-cpu`, libvirt qemu log |
| `ERROR` + port binding / vif plugging | `devstack@q-svc`, `openstack network agent list` |
| `ACTIVE` but no IP / no SSH | console log, security group rules, subnet DHCP, router |
| Volume stuck in `creating`/`error` | `openstack volume service list`, `devstack@c-sch`, `devstack@c-vol` |
| Horizon error page | `/var/log/apache2/horizon_error.log` |

## Scenarios

Prerequisite: labs 02-05 done. Clean up between runs with `./scripts/07-troubleshooting-demos.sh cleanup`.

### 1. `no-valid-host`: scheduler cannot place the instance
Launches with a flavor demanding a 100 TB root disk.
* **Symptom:** instance goes to `ERROR`; fault says *No valid host was found*.
* **Diagnose:** tenant view is generic. As admin, `journalctl -u devstack@n-sch` shows the scheduler found no allocation candidates, and `openstack hypervisor list --long` shows how much disk the node really has.
* **Root cause:** request exceeds the host's capacity.
* **Fix:** pick a flavor that fits.

### 2. `quota`: project limit reached
* **Symptom:** the CLI returns an error immediately (HTTP 403, *Quota exceeded for instances*). No instance is created, so there is nothing in the scheduler log; this is rejected in the API.
* **Diagnose:** `openstack limits show --absolute`, or as admin `openstack quota show lab-project`.
* **Fix:** delete unused instances or raise the quota.

### 3. `small-disk`: image does not fit the flavor
* **Symptom:** HTTP 400, flavor disk too small for the requested image (image `min_disk` is 20 GB, flavor disk is 1 GB).
* **Diagnose:** compare `openstack image show ... -c min_disk` with `openstack flavor show ... -c disk`.
* **Fix:** larger flavor, or correct the image's `min_disk`.

### 4. `no-dhcp`: ACTIVE but no network
* **Symptom:** status `ACTIVE`, yet no IP and no connectivity.
* **Diagnose:** `openstack console log show` shows the guest broadcasting DHCP requests and never getting a lease, plus failing metadata requests. `openstack subnet show ... -c enable_dhcp` reveals `False`.
* **Lesson:** `ACTIVE` only means the hypervisor started the VM. It says nothing about the guest's networking.
* **Fix:** `openstack subnet set --dhcp <subnet>` and reboot the instance.

### 5. `cinder-down`: block storage service stopped
* **Symptom:** a new volume stays in `creating`.
* **Diagnose:** `openstack volume service list` shows `cinder-volume` as `down`; `systemctl status devstack@c-vol` confirms it is stopped.
* **Fix:** `sudo systemctl start devstack@c-vol`. (The script restarts it for you.)

## Other failures worth knowing

| Failure | Typical cause | Check / fix |
|---------|---------------|-------------|
| Instance `ERROR`: *Build of instance aborted ... Image ... could not be found* | Image deleted/deactivated | `openstack image list`, `image set --activate` |
| `Timed out waiting for network-vif-plugged` | Neutron agent / OVN down, host overloaded | `openstack network agent list`, restart `devstack@q-svc`, check RAM/CPU |
| Volume attach fails: *volume is not available* | Volume still `in-use` elsewhere or in `error` | `openstack volume show`, detach first |
| Can ping but not SSH | Missing tcp/22 rule, or wrong key / username | security group rules; user is `cirros` / `ubuntu` |
| Can SSH from host, not from laptop | Floating IP range only exists on the host | see [Lab 05](05-neutron-networking.md#reaching-floating-ips-from-outside-the-host) |
| 401 right after changing a password | Old token / stale `OS_PASSWORD` | re-source the openrc file |
| Instances very slow | No KVM, QEMU emulation | `ls /dev/kvm`; enable nested virtualisation |

## After a reboot

DevStack is not designed to survive reboots reliably, so expect some services to need attention:

```bash
systemctl list-units 'devstack@*' --all     # what came back?
sudo vgs                                    # Cinder's volume group missing? its loopback device may be detached
sudo losetup -a
sudo systemctl restart 'devstack@*'
```

If it will not recover, the supported path is to re-run `./stack.sh` (or `./unstack.sh && ./stack.sh`) from `/opt/stack/devstack` as the `stack` user, or revert to the VM snapshot taken after install.

## What to record for your write-up

For each scenario: the command you ran, the symptom you saw, **the exact log line that explained it**, and the fix. That table is the most convincing part of this project for a reader.

**Screenshots:** failed instance with fault message in Horizon, scheduler journal lines, console log of the no-DHCP guest, `volume service list` showing `down`.
