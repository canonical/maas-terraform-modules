# How to setup MAAS DHCP

You likely want to have a subnet available in MAAS that has DHCP enabled, perhaps to use as a PXE subnet. To enable MAAS-provided DHCP on a rack controller requires having a subnet available that will be used for DHCP, and an additional interface on the relevant rack controller connected to this subnet. This guide details the steps required to achieve this.

## Prerequisites

Before following this guide, ensure:
1. You have run the `maas-deploy` module.
2. You have identified the target rack controller hostname to enable DHCP on.

## Create a PXE subnet
Create a subnet for MAAS to serve DHCP from. If you already have one created, you can skip this section.


The LXD network must be created with DHCP disabled so that MAAS can provide DHCP. It may require NAT depending on your needs:
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
1. Identify the rack controller you would like MAAS to provide DHCP from. If `enable_rack_mode=True`, this will be a machine listed in the `terragrunt stack output maas_deploy.maas_machines` of the `maas-deploy` module.
2. Attach the desired network (`maas-pxe`) to the desired rack controller (`$NAME`, for example `juju-2c9858-1`) as a new interface (`eth1`):
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
   ```
4. As root, setup this interface with netplan using the identified name:
   ```
   netplan set --origin-hint 99-maas-pxe-network ethernets.enp6s0.addresses=[10.20.0.2/24]
   netplan apply
   ```
   > [!NOTE]
> The above addresses assume you may want to set a gateway as 10.20.0.1, which is outside of the scope of this document.
5. After a few moments, you should be able to see the relevant subnet discovered in MAAS, if network discovery is enabled. You can now use this network to enable DHCP using Terragrunt.

## Enable DHCP on the discovered subnet with Terragrunt

Because this setup is specific to your infrastructure, DHCP configuration is not part of the shared modules. Instead, create a small local module in your deployment repo and add it as a unit in your existing stack.

1. In your deployment repo, create the following files and copy the contents into them below:

   `modules/maas-dhcp/variables.tf`
   ```hcl
   variable "maas_url" {
     description = "The MAAS URL in the format of: http://127.0.0.1:5240/MAAS"
     type        = string
   }

   variable "maas_key" {
     description = "The MAAS API key"
     type        = string
   }

   variable "rack_controller" {
     description = "The hostname of the MAAS rack controller to enable DHCP on"
     type        = string
   }

   variable "pxe_subnet" {
     description = "The subnet CIDR to serve DHCP from the MAAS rack controller"
     type        = string
   }
   ```

   `modules/maas-dhcp/versions.tf`
   ```hcl
   terraform {
     required_providers {
       maas = {
         source  = "canonical/maas"
         version = "~> 2.6"
       }
     }
   }
   ```

   `modules/maas-dhcp/main.tf`
   ```hcl
   provider "maas" {
     api_key = var.maas_key
     api_url = var.maas_url
   }

   data "maas_rack_controller" "dhcp_rack" {
     hostname = var.rack_controller
   }

   data "maas_subnet" "pxe" {
     cidr = var.pxe_subnet
   }

   data "maas_fabric" "pxe_fabric" {
     name = data.maas_subnet.pxe.fabric
   }

   resource "maas_subnet_ip_range" "dhcp_range" {
     subnet   = data.maas_subnet.pxe.id
     type     = "dynamic"
     start_ip = cidrhost(data.maas_subnet.pxe.cidr, 99)
     end_ip   = cidrhost(data.maas_subnet.pxe.cidr, 254)
   }

   resource "maas_vlan_dhcp" "dhcp_enabled" {
     fabric                  = data.maas_fabric.pxe_fabric.id
     vlan                    = data.maas_subnet.pxe.vid
     primary_rack_controller = data.maas_rack_controller.dhcp_rack.id
     ip_ranges               = [maas_subnet_ip_range.dhcp_range.id]
   }
   ```

   `modules/maas-dhcp/terragrunt.hcl`
   ```hcl
   include "root" {
     path = find_in_parent_folders("root.hcl")
   }

   terraform {
     source = "${get_terragrunt_dir()}//"
   }

   dependency "maas_deploy" {
     config_path = values.maas_deploy_path

     mock_outputs_merge_strategy_with_state = "shallow"

     mock_outputs = {
       maas_api_url = "http://mock-maas"
       maas_api_key = "mock-password"
     }
   }

   inputs = {
     maas_url        = dependency.maas_deploy.outputs.maas_api_url
     maas_key        = dependency.maas_deploy.outputs.maas_api_key
     rack_controller = values.rack_controller
     pxe_subnet      = values.pxe_subnet
   }
   ```

2. Add the following unit to your `terragrunt.stack.hcl`, after the `maas_config` unit. Update the `source` path to point to your local `maas-dhcp` module you've just created, `<$NAME>` with the rack controller hostname (e.g. `juju-2c9858-1`) and adjust the subnet if needed:

   ```hcl
   unit "maas_dhcp" {
     source = "./modules/maas-dhcp"
     path   = "maas-dhcp"

     values = {
       maas_deploy_path = "../maas-deploy"
       rack_controller  = "<$NAME>"
       pxe_subnet       = "10.20.0.0/24"
     }
   }
   ```

3. Apply the stack:
   ```bash
   terragrunt stack run apply
   ```
   DHCP should now be enabled on the specified rack.
