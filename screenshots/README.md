# Screenshots

Evidence that the lab ran. Add your own images here and reference them from the main README.
Suggested file names (so the checklist stays tidy):

| File | Capture |
|------|---------|
| `01-horizon-login.png` | Horizon login page |
| `01-system-information.png` | Admin → System → System Information (all services) |
| `01-hypervisors.png` | Admin → Compute → Hypervisors |
| `02-project-members.png` | Project members and roles (member / reader) |
| `02-reader-403.png` | Terminal: reader user denied creating a network |
| `03-images.png` | Image list with CirrOS (and Ubuntu) |
| `04-flavors.png` | Custom flavors |
| `04-instances-active.png` | Instances list, status ACTIVE |
| `04-console.png` | Instance console |
| `05-network-topology.png` | Project → Network → Network Topology |
| `05-security-group-rules.png` | Security group rules |
| `05-floating-ips.png` | Floating IP list and association |
| `05-isolation-ping.png` | Terminal: ping across isolated networks failing |
| `06-volumes.png` | Volume in-use + snapshot list |
| `06-restored-proof.png` | Terminal: restored volume still has the original file |
| `07-failed-instance.png` | Instance in ERROR with fault message |
| `07-scheduler-log.png` | `journalctl -u devstack@n-sch` showing the cause |
| `07-volume-service-down.png` | `openstack volume service list` with cinder-volume down |

Tips: crop out passwords and tokens before committing, and keep each file under ~500 KB.
