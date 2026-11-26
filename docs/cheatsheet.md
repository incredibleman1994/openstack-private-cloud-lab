# OpenStack CLI cheat sheet

```bash
source /opt/stack/devstack/openrc admin admin     # admin credentials
source labuser-openrc.sh                          # tenant credentials (created by lab 02)
openstack --help | less ; openstack server create --help
```

Add `--debug` to any command to see the HTTP requests. Add `-f json` / `-f value -c <column>` for scripting.

## Keystone
```bash
openstack project list | create | delete
openstack user create --domain default --password-prompt --project <proj> <name>
openstack role list
openstack role add --project <proj> --user <user> member
openstack role assignment list --project <proj> --names
openstack quota show <proj> ; openstack quota set --instances 6 <proj>
openstack token issue ; openstack catalog list ; openstack endpoint list
```

## Glance
```bash
openstack image create --file x.img --disk-format qcow2 --container-format bare --public <name>
openstack image list ; openstack image show <name>
openstack image set --property os_distro=ubuntu --tag lab <name>
openstack image set --deactivate <name>   # and --activate
openstack image save --file out.img <name>
openstack image delete <name>
```

## Nova
```bash
openstack flavor create --vcpus 1 --ram 512 --disk 5 <name>
openstack keypair create --public-key ~/.ssh/id_ed25519.pub <name>
openstack server create --flavor F --image I --network N --security-group SG --key-name K --wait <vm>
openstack server list | show <vm> | delete <vm>
openstack server stop|start|pause|unpause|suspend|resume <vm>
openstack server reboot --soft|--hard <vm>
openstack server image create --name <snap> <vm>
openstack console log show <vm> ; openstack console url show <vm>
openstack server event list <vm>
openstack limits show --absolute
openstack compute service list ; openstack hypervisor list
```

## Neutron
```bash
openstack network create N ; openstack subnet create --network N --subnet-range 10.0.0.0/24 S
openstack router create R ; openstack router set R --external-gateway public
openstack router add subnet R S
openstack security group create SG
openstack security group rule create --ingress --protocol tcp --dst-port 22 SG
openstack floating ip create public
openstack server add floating ip <vm> <ip>
openstack port list --server <vm>
openstack network agent list
```

## Cinder
```bash
openstack volume create --size 1 V
openstack server add volume <vm> V ; openstack server remove volume <vm> V
openstack volume snapshot create --volume V [--force] SNAP
openstack volume create --snapshot SNAP V2
openstack volume set --size 2 V               # extend (detached)
openstack volume list ; openstack volume service list
```

## Logs and services (DevStack)
```bash
systemctl list-units 'devstack@*'
sudo journalctl -u devstack@n-cpu -f
sudo journalctl -u 'devstack@n-*' --since "10 min ago" --no-pager | grep -i error
sudo journalctl -u 'devstack@*' --no-pager | grep req-<request-id>     # follow one request across services
sudo tail -f /var/log/apache2/horizon_error.log
sudo ls /var/log/libvirt/qemu/
```
