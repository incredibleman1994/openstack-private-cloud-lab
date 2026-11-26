# Lab 02: Keystone - projects, users, roles

**Goal:** create a tenant (project) with a normal user and a read-only user, and prove that roles actually restrict what each can do.

**Automated:** `./scripts/01-keystone-setup.sh`

## Concepts

| Term | Meaning |
|------|---------|
| Domain | Container for projects/users. DevStack uses `Default`. |
| Project | Tenant that owns resources (instances, networks, volumes) and has quotas. |
| User | Identity that authenticates. |
| Role | Permission level granted to a user **on a project**. Default roles: `admin`, `member`, `reader`. |

## CLI

```bash
source /opt/stack/devstack/openrc admin admin

# Project and users
openstack project create --domain default --description "Private cloud lab" lab-project
openstack user create --domain default --password-prompt --project lab-project labuser
openstack user create --domain default --password-prompt --project lab-project labreader

# Roles: assign on the project
openstack role list
openstack role add --project lab-project --user labuser   member
openstack role add --project lab-project --user labreader reader
openstack role assignment list --project lab-project --names

# Quotas keep one tenant from eating the whole host
openstack quota set --instances 6 --cores 8 --ram 6144 --volumes 6 --gigabytes 20 lab-project
openstack quota show lab-project
```

### Inspect authentication

```bash
openstack token issue                 # the token a client presents to every API
openstack catalog list                # which service lives at which endpoint
openstack endpoint list
```

### Prove RBAC works

`01-keystone-setup.sh` writes `labuser-openrc.sh` and `labreader-openrc.sh` (git-ignored).

```bash
# Reader: may look, may not touch
source labreader-openrc.sh
openstack server list                                   # works (empty list)
openstack network create should-fail                    # expect HTTP 403 (policy does not allow)

# Member: full control inside its own project
source labuser-openrc.sh
openstack network create it-works && openstack network delete it-works
openstack project list                                  # members cannot list all projects -> 403
```

Record the exact error messages; they are a good README/blog snippet.

> **Release-dependent behaviour:** how strictly `reader` is enforced depends on the policy defaults of the OpenStack release you installed. Recent releases enforce the newer RBAC defaults, so the reader is denied. If your reader *can* create resources, that is a legitimate finding to write up; check the DevStack docs for your release for the option that enables the newer policy defaults (e.g. `ENFORCE_SCOPE` in `local.conf`) and re-run `stack.sh`.

## Horizon

1. **Identity → Projects → Create Project**: name `lab-project`.
2. **Identity → Users → Create User**: name `labuser`, primary project `lab-project`, role `member`. Repeat for `labreader` with role `reader`.
3. **Identity → Projects → (dropdown) Manage Members** to see/change roles per user.
4. **Identity → Projects → (dropdown) Modify Quotas** to set instances/vCPUs/RAM/volumes.
5. Log out and log in as `labuser`; note that the **Admin** and **Identity** panels have disappeared.

**Screenshots:** project members/roles, quota page, the 403 error from the reader.

Next: [Lab 03 - Glance](03-glance-images.md)
