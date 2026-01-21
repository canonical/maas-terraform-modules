terraform {
  required_providers {
    maas = {
      source  = "canonical/maas"
      version = "~> 2.0"
    }
  }
}

variable "pxe_subnet_cidr" {
  type = string
}

variable "rack_controller" {
  type = string
}

variable "lxd_trust_token" {
  description = "LXD trust token or password for authentication"
  type        = string
  sensitive   = true
}

variable "juju_model" {
  description = "The Juju model name where MAAS is deployed"
  type        = string
}

data "external" "maas_machines" {
  program = ["bash", "${path.module}/scripts/get-maas-machine-ids.sh"]

  query = {
    model   = var.juju_model
    is_maas = "true"
  }
}

data "external" "non_maas_machines" {
  program = ["bash", "${path.module}/scripts/get-maas-machine-ids.sh"]

  query = {
    model   = var.juju_model
    is_maas = "false"
  }
}

resource "terraform_data" "maas_static_ip_on_pxe" {
  for_each = toset(split(",", data.external.maas_machines.result.machine_ids))

  input = {
    machine_ids = data.external.maas_machines.result.machine_ids
  }

  provisioner "local-exec" {
    command = <<-EOT
      juju exec -m "${var.juju_model}" --machine "${each.value}" -- sudo netplan set --origin-hint=999-custom 'network.ethernets.enp6s0={addresses: [${cidrhost(var.pxe_subnet_cidr, tonumber(each.value) + 2)}/${split("/", var.pxe_subnet_cidr)[1]}]}'
      juju exec -m "${var.juju_model}" --machine "${each.value}" -- sudo netplan apply
      juju exec -m "${var.juju_model}" --machine "${each.value}" -- sudo systemctl restart jujud-machine-"${each.value}"
      juju exec -m "${var.juju_model}" --machine "${each.value}" -- sudo snap restart maas
      sleep 120
    EOT
  }
}

resource "terraform_data" "non_maas_disable_ip_on_pxe" {
  for_each = toset(split(",", data.external.non_maas_machines.result.machine_ids))

  input = {
    machine_ids = data.external.non_maas_machines.result.machine_ids
  }

  provisioner "local-exec" {
    command = <<-EOT
      juju exec -m "${var.juju_model}" --machine "${each.value}" -- sudo netplan set --origin-hint=999-custom 'network.ethernets.enp6s0={activation-mode: off}'
      juju exec -m "${var.juju_model}" --machine "${each.value}" -- sudo netplan apply
      juju exec -m "${var.juju_model}" --machine "${each.value}" -- sudo systemctl restart jujud-machine-"${each.value}"
    EOT
  }
}

data "maas_subnet" "pxe" {
  cidr       = var.pxe_subnet_cidr
  depends_on = [terraform_data.maas_static_ip_on_pxe]
}

data "maas_fabric" "pxe_vlan_fabric" {
  name = data.maas_subnet.pxe.fabric
}

data "maas_rack_controller" "controller" {
  hostname = var.rack_controller
}

resource "maas_subnet_ip_range" "pxe_dhcp_range" {
  subnet   = data.maas_subnet.pxe.id
  type     = "dynamic"
  start_ip = cidrhost(var.pxe_subnet_cidr, 100)
  end_ip   = cidrhost(var.pxe_subnet_cidr, 200)

  depends_on = [terraform_data.maas_static_ip_on_pxe]
}

resource "maas_vlan_dhcp" "pxe" {
  fabric                  = data.maas_fabric.pxe_vlan_fabric.id
  vlan                    = data.maas_subnet.pxe.vid
  ip_ranges               = [maas_subnet_ip_range.pxe_dhcp_range.id]
  primary_rack_controller = data.maas_rack_controller.controller.id
}

# Register LXD VM host
resource "maas_vm_host" "lxd_host" {
  type          = "lxd"
  power_address = "https://10.0.2.1:8443"
  project       = "maas-test"
  password      = var.lxd_trust_token

  # Wait for MAAS to process the VM host registration
  # TODO: Remove when https://github.com/canonical/terraform-provider-maas/issues/404 is resolved
  provisioner "local-exec" {
    command = "sleep 60"
  }

  depends_on = [terraform_data.maas_static_ip_on_pxe]
}

# Create LXD VM host machine
resource "maas_vm_host_machine" "vm" {
  vm_host  = maas_vm_host.lxd_host.id
  hostname = "acceptance-vm"
  cores    = 1
  memory   = 2048

  depends_on = [maas_vlan_dhcp.pxe]
}

output "maas_vm_host_id" {
  description = "The ID of the registered MAAS VM host"
  value       = maas_vm_host.lxd_host.id
}
