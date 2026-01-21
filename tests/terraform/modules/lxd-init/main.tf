terraform {
  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "~> 2.6"
    }
  }
}

# Create trust tokens
resource "lxd_trust_token" "maas_charms" {
  name = "maas-charms"
}

resource "lxd_trust_token" "vm_host" {
  name = "vh-host"
}

# Create the network
resource "lxd_network" "net_test" {
  name = "net-test"
  type = "bridge"

  config = {
    "ipv4.address" = "10.0.2.1/24"
    "ipv4.dhcp"    = "false"
    "ipv4.nat"     = "true"
    "ipv6.address" = "none"
    "ipv6.nat"     = "true"
  }
}

# Create MAAS system project
resource "lxd_project" "maas_system" {
  name        = "maas-system"
  description = "MAAS lab system environment"

  config = {
    "features.images"          = "true"
    "features.profiles"        = "true"
    "features.storage.volumes" = "true"
  }
}

# Create MAAS test project
resource "lxd_project" "maas_test" {
  name        = "maas-test"
  description = "MAAS lab test VMs environment"

  config = {
    "features.images"          = "true"
    "features.profiles"        = "true"
    "features.storage.volumes" = "true"
  }
}

# Configure default profile in MAAS system project
resource "lxd_profile" "maas_system_default" {
  name        = "default"
  project     = lxd_project.maas_system.name
  description = "MAAS system default profile"

  config = {
    "security.nesting" = "true"
  }

  device {
    name = "enp5s0"
    type = "nic"
    properties = {
      name    = "enp5s0"
      network = "lxdbr0"
    }
  }

  device {
    name = "enp6s0"
    type = "nic"
    properties = {
      name    = "enp6s0"
      nictype = "bridged"
      parent  = lxd_network.net_test.name
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = "default"
    }
  }
}

# Configure default profile in MAAS test project
resource "lxd_profile" "maas_test_default" {
  name        = "default"
  project     = lxd_project.maas_test.name
  description = "MAAS test VMs default profile"

  config = {
    "limits.memory"       = "2GiB"
    "security.nesting"    = "true"
    "security.secureboot" = "false"
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      "boot.priority" = "1"
      name            = "enp5s0"
      network         = lxd_network.net_test.name
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = "default"
    }
  }
}

# Output the trust tokens
output "maas_charms_token" {
  value       = lxd_trust_token.maas_charms.token
  description = "Trust token for maas-charms"
  sensitive   = true
}

output "maas_vm_host_token" {
  value       = lxd_trust_token.vm_host.token
  description = "Trust token for VM host"
  sensitive   = true
}
