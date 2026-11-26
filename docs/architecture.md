# Architecture

## Services in this lab

```mermaid
flowchart LR
  U["Horizon dashboard / OpenStack CLI"] --> KS["Keystone<br/>identity + service catalog"]
  U --> NOVA["Nova<br/>compute API"]
  U --> GL["Glance<br/>images"]
  U --> NEU["Neutron<br/>networking"]
  U --> CIN["Cinder<br/>block storage"]
  NOVA --> PL["Placement<br/>resource inventory"]
  NOVA --> LV["libvirt + KVM/QEMU"]
  NOVA -. fetch image .-> GL
  NOVA -. create ports .-> NEU
  NOVA -. attach volume .-> CIN
  CIN --> LVM[("LVM volume group<br/>on loopback file")]
  subgraph INFRA["Shared infrastructure"]
    DB[("MySQL")]
    MQ[["RabbitMQ"]]
  end
  KS --- DB
  NOVA --- MQ
```

| Service | Role | DevStack unit (journal) |
|---------|------|-------------------------|
| Keystone | Authentication, projects, users, roles, service catalog | `devstack@keystone` |
| Glance | Image registry and storage | `devstack@g-api` |
| Placement | Tracks resource inventory/usage for scheduling | `devstack@placement-api` |
| Nova | `n-api`, `n-sch` (scheduler), `n-cond-cell1` (conductor), `n-cpu` (compute) | `devstack@n-*` |
| Neutron | API server (`q-svc`) + OVN backend | `devstack@q-svc`, `ovn-*` |
| Cinder | `c-api`, `c-sch`, `c-vol` | `devstack@c-*` |
| Horizon | Web UI served by Apache | `apache2`, `/var/log/apache2/horizon_error.log` |

List what is actually running on your host: `systemctl list-units 'devstack@*'`.

## What happens when you launch an instance

```mermaid
sequenceDiagram
  actor User
  participant API as Nova API
  participant KS as Keystone
  participant SCH as Scheduler
  participant PL as Placement
  participant CPU as nova-compute
  participant GL as Glance
  participant NEU as Neutron
  User->>API: POST /servers (token)
  API->>KS: validate token + policy
  API->>API: check quota, flavor/image compatibility
  API->>SCH: schedule request (via RabbitMQ)
  SCH->>PL: allocation candidates for flavor
  PL-->>SCH: host(s) with capacity
  SCH->>CPU: build instance on chosen host
  CPU->>GL: download image
  CPU->>NEU: create/bind port, get IP
  CPU->>CPU: libvirt defines + starts the guest
  CPU-->>API: status ACTIVE
```

Where it can fail, and which log to read:

| Stage | Typical failure | Look at |
|-------|-----------------|---------|
| Token / policy | 401 / 403 | `devstack@keystone`, role assignments |
| Quota, flavor vs image | HTTP 403 / 400 returned immediately | `openstack limits show`, flavor + image properties |
| Scheduling | `No valid host was found` | `devstack@n-sch`, `devstack@placement-api` |
| Build on host | status `ERROR`, fault message | `devstack@n-cpu`, `/var/log/libvirt/qemu/` |
| Networking | port binding failed, no IP | `devstack@q-svc`, console log |
| Volume | stuck `creating` / `error` | `devstack@c-sch`, `devstack@c-vol`, `openstack volume service list` |

## Network layout

| Network | CIDR | Purpose |
|---------|------|---------|
| `public` (created by DevStack) | `172.24.4.0/24` | External network / floating IP pool, attached to `br-ex` |
| `lab-net` | `192.168.10.0/24` | Routed tenant network (via `lab-router`) |
| `lab-isolated-net` | `192.168.20.0/24` | Tenant network with **no router**, proves isolation |

Names and CIDRs are set in [`config/lab.env`](../config/lab.env).
