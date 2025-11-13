# How to setup MAAS DHCP

To enable MAAS-provided DHCP on a rack controller requires having a subnet that will be used for DHCP, and an additional interface on the relevant rack controllers connected to this subnet. This guide details the manual steps required to achieve this, as there is no current way to manage this with Terraform.

## Prerequisites

Before following this guide, ensure:
1. You have run the `maas-deploy` module.
2. You have identified the target rack controller hostname from `terraform output maas_machines`
3. You have network administrative access to your deployment platform (LXD/MicroCloud)

## Create a PXE subnet
If you haven't already, create a subnet for MAAS to serve DHCP from.

### LXD setup
Creating a LXD network requires DHCP being disabled, so that MAAS can manage it, and may require NAT depending on your needs:
```bash
lxc network create maas-pxe
cat << __EOF | lxc network edit maas-pxe
config:
    ipv4.address: 10.20.0.1/24
    ipv4.dhcp: "false"
    ipv4.nat: "true"
    ipv6.address: none
description: ""
name: maas-pxe
type: bridge
used_by: []
managed: true
status: Created
locations:
- none
__EOF
```
## Attach the network to the rack controller
1. Identify the rack controller(s) you would like MAAS to provide DHCP from. If `enable_rack_mode=True`, this will be the machines listed in the `terraform output` of the `maas-deploy` module.
2. Attach the desired network (`maas-pxe`) to the desired rack controller(s) (`$NAME`, for example `juju-2c9858-1`) as a new interface (`eth1`):
   ```
   lxc network attach maas-pxe $NAME eth1
   ```
3. SSH into the rack controller and identify the name of the new interface. It will be named differently to `eth1`, in this example `enp6s0`:
   ```bash
    ❯ lxc shell $NAME
    root@juju-9f8b50-1:~# ip a
    1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
        ...
        ...
        ...
    2: enp5s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
        ...
        ...
        ...
    3: enp6s0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000    # The unconfigured interface
        link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
4. As root, setup this interface with netplan using the identified name:
   ```
   netplan set --origin-hint 99-maas-pxe-network ethernets.enp6s0.addresses=[10.20.0.2/24]
   netplan apply
   ```
5. After a few moments, you should be able to see the relevant subnet discovered in MAAS, if network discovery is enabled. You can now use this network to enable DHCP using terraform.

## Enable DHCP on the discovered subnet with Terraform
You can now enable DHCP with Terraform:

1. Add the following to
   `/modules/maas-config/main.tf`
   ```hcl
   # Enable DHCP
   data "maas_rack_controller" "dhcp_rack" {
     count = var.enable_dhcp ? 1 : 0

     hostname = var.rack_controller
   }

   data "maas_subnet" "pxe" {
     count = var.enable_dhcp ? 1 : 0

     cidr = var.pxe_subnet
   }

   data "maas_fabric" "pxe_fabric" {
     count = var.enable_dhcp ? 1 : 0

     name = data.maas_subnet.pxe[0].fabric
   }

   resource "maas_subnet_ip_range" "dhcp_range" {
     count = var.enable_dhcp ? 1 : 0

     subnet   = data.maas_subnet.pxe[0].id
     type     = "dynamic"
     start_ip = cidrhost(data.maas_subnet.pxe[0].cidr, 99)
     end_ip   = cidrhost(data.maas_subnet.pxe[0].cidr, 254)
   }

   resource "maas_vlan_dhcp" "dhcp_enabled" {
     count = var.enable_dhcp ? 1 : 0

     fabric                  = data.maas_fabric.pxe_fabric[0].id
     vlan                    = data.maas_subnet.pxe[0].vid
     primary_rack_controller = data.maas_rack_controller.dhcp_rack[0].id
     ip_ranges               = [maas_subnet_ip_range.dhcp_range[0].id]
   }
   ```
   `modules/maas-config/variables`
   ```hcl
   variable "enable_dhcp" {
     description = <<EOF
       Whether to enable DHCP for a given subnet on a specified rack controller
       If you enable this you also need to specify pxe_subnet below
     EOF
     type        = bool

     default = false
   }

   variable "rack_controller" {
     description = "The hostname of the MAAS rack controller to enable DHCP on"
     type        = string
   }

   variable "pxe_subnet" {
     description = "The subnet to serve DHCP from the MAAS rack controller"
     type        = string
   }
   ```
   `config/maas-config/config.tfvars`, filling out the appropriate values
   ```hcl
   # Whether to enable DHCP for a given subnet on a specified rack controller
   enable_dhcp = true
   # The hostname of the MAAS rack controller to enable DHCP
   rack_controller = <$NAME of rack controller>
   # The subnet to serve DHCP from the MAAS rack controller
   pxe_subnet = "10.20.0.0/24"
   ```
1. Apply your new `maas-config` plan. You're done, DHCP should now be enabled on the specified rack.
