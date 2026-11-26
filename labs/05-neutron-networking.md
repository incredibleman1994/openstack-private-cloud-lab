# Lab 05: Neutron - networks, routers, security groups, floating IPs

**Goal:** build a routed tenant network and an isolated one, control traffic with security groups, and expose an instance with a floating IP.

**Automated:** `./scripts/04-neutron-network.sh`, then `./scripts/05-launch-instances.sh` (launches the instances and runs the connectivity and isolation tests)

```
             public (172.24.4.0/24)  <- floating IPs
                     |
               [ lab-router ]  (SNAT + floating IP DNAT)
                     |
        lab-net 192.168.10.0/24 ---- lab-vm1
        lab-isolated-net 192.168.20.0/24 ---- lab-vm-isolated   (no router)
```

## CLI (as the tenant user)

```bash
source labuser-openrc.sh

# Routed network
openstack network create lab-net
openstack subnet create --network lab-net --subnet-range 192.168.10.0/24 \
  --dns-nameserver 8.8.8.8 lab-subnet

# Isolated network: same thing, but it will never be attached to a router
openstack network create lab-isolated-net
openstack subnet create --network lab-isolated-net --subnet-range 192.168.20.0/24 lab-isolated-subnet

# Router: external gateway on 'public', interface on lab-subnet
openstack router create lab-router
openstack router set lab-router --external-gateway public
openstack router add subnet lab-router lab-subnet
openstack router show lab-router
```

### Security groups

A security group is a stateful firewall applied to an instance's port. The default for ingress is **deny**, for egress **allow**.

```bash
openstack security group create --description "ICMP + SSH" lab-sg-ssh-icmp
openstack security group rule create --ingress --protocol icmp            lab-sg-ssh-icmp
openstack security group rule create --ingress --protocol tcp --dst-port 22 lab-sg-ssh-icmp

openstack security group create --description "HTTP + HTTPS" lab-sg-web
openstack security group rule create --ingress --protocol tcp --dst-port 80  lab-sg-web
openstack security group rule create --ingress --protocol tcp --dst-port 443 lab-sg-web

openstack security group rule list lab-sg-ssh-icmp
```

### Floating IP

```bash
openstack floating ip create public                    # allocate from the external pool
openstack server add floating ip lab-vm1 <floating-ip>
openstack floating ip list
ssh -i ~/.ssh/lab-key cirros@<floating-ip>             # from the DevStack host
curl http://<floating-ip>/                             # the user-data web server
```

## Experiments (do these, they teach the most)

**1. Security groups really block traffic**
```bash
RULE=$(openstack security group rule list lab-sg-ssh-icmp --protocol tcp -f value -c ID)
openstack security group rule delete $RULE
ssh -i ~/.ssh/lab-key -o ConnectTimeout=5 cirros@<fip>      # times out (ping still works)
openstack security group rule create --ingress --protocol tcp --dst-port 22 lab-sg-ssh-icmp   # restore
```

**2. Network isolation**
```bash
ssh -i ~/.ssh/lab-key cirros@<fip-of-lab-vm1>
$ ping -c2 <ip of lab-vm-isolated>          # 100% loss: different L2 network, no router between them
```
Now connect the networks and watch it start working:
```bash
openstack router add subnet lab-router lab-isolated-subnet
# ...ping again from lab-vm1: replies. Undo with:
openstack router remove subnet lab-router lab-isolated-subnet
```
(The isolated VM may need a DHCP renewal or reboot to learn the route.)

**3. Outbound internet through the router (SNAT)**
```bash
$ ping -c2 8.8.8.8     # from inside lab-vm1; works because lab-router NATs to the external network
```

**4. Floating IP lifecycle**
```bash
openstack server remove floating ip lab-vm1 <fip>      # instance keeps its private IP, loses the public one
openstack floating ip delete <fip>
```

## Inspect

```bash
openstack port list --server lab-vm1
openstack network agent list           # OVN controller / metadata agents
openstack network show lab-net
```

## Horizon

* **Project → Network → Network Topology** gives a live diagram of networks, router and instances. Great screenshot.
* **Project → Network → Networks → Create Network** (wizard: network, subnet, subnet details).
* **Project → Network → Routers → Create Router**, set gateway to `public`, then router name → **Interfaces → Add Interface**.
* **Project → Network → Security Groups → Create → Manage Rules → Add Rule.**
* **Project → Network → Floating IPs → Allocate IP To Project → Associate.**

## Reaching floating IPs from outside the host

By default `public` (172.24.4.0/24) lives on a bridge inside the DevStack host, so only the host can reach it. Easiest ways to reach instances from your laptop:

```bash
# SSH jump through the DevStack host
ssh -J <user>@<HOST_IP> -i ~/.ssh/lab-key cirros@<floating-ip>

# or add a route on your laptop (Linux) - needs a bridged/host-only network, not NAT
sudo ip route add 172.24.4.0/24 via <HOST_IP>
```

**Screenshots:** network topology, router interfaces, security group rules, floating IP list, the failed isolation ping.

Next: [Lab 06 - Cinder](06-cinder-storage.md)
