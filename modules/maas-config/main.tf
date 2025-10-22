provider "maas" {
  api_key = var.maas_key
  api_url = var.maas_url
}

# 0
# Enable DHCP
data "maas_rack_controller" "dhcp_rack" {
  count = var.enable_dhp ? 1 : 0

  hostname = var.rack_controller
}

data "maas_subnet" "pxe" {
  count = var.enable_dhp ? 1 : 0

  cidr = var.pxe_subnet
}

data "maas_fabric" "pxe_fabric" {
  count = var.enable_dhp ? 1 : 0

  name = data.maas_subnet.pxe[0].fabric
}

resource "maas_subnet_ip_range" "dhcp_range" {
  count = var.enable_dhp ? 1 : 0

  subnet   = data.maas_subnet.pxe[0].id
  type     = "dynamic"
  start_ip = cidrhost(data.maas_subnet.pxe[0].cidr, 99)
  end_ip   = cidrhost(data.maas_subnet.pxe[0].cidr, 254)
}

resource "maas_vlan_dhcp" "dhcp_enabled" {
  count = var.enable_dhp ? 1 : 0

  fabric                  = data.maas_fabric.pxe_fabric[0].id
  vlan                    = data.maas_subnet.pxe[0].vid
  primary_rack_controller = data.maas_rack_controller.dhcp_rack[0].id
  ip_ranges               = [maas_subnet_ip_range.dhcp_range[0].id]
}

# 1
# Set boot source
resource "maas_boot_source" "image_server" {
  url              = var.image_server_url
  keyring_filename = "/snap/maas/current/usr/share/keyrings/ubuntu-cloudimage-keyring.gpg"
}

# 2
# Set boot source selections
resource "maas_boot_source_selection" "images" {
  for_each = var.boot_selections

  boot_source = maas_boot_source.image_server.id
  os          = "ubuntu"
  release     = each.key
  arches      = each.value.arches
  subarches   = each.value.subarches
}

# 3
# Set MAAS config options
resource "maas_configuration" "config" {
  for_each = var.maas_config

  key   = each.key
  value = each.value
}

# 4
# Set MAAS package repositories
resource "maas_package_repository" "package_repositories" {
  for_each = var.package_repositories

  name = each.key
  url  = each.value.url

  arches              = each.value.arches
  components          = each.value.components
  disable_sources     = each.value.disable_sources
  disabled_components = each.value.disabled_components
  disabled_pockets    = each.value.disabled_pockets
  distributions       = each.value.distributions
  enabled             = each.value.enabled
  key                 = each.value.key
}

# 5
# Setup tags
resource "maas_tag" "tags" {
  for_each = var.tags

  name        = each.key
  comment     = each.value.comment
  kernel_opts = each.value.kernel_opts
  definition  = each.value.definition
}

# 6
# Setup domains
resource "maas_dns_domain" "domains" {
  for_each = var.domains

  name          = each.key
  authoritative = each.value.authoritative
  is_default    = each.value.is_default
  ttl           = each.value.ttl
}

# 7
# Setup DNS domain records
resource "maas_dns_record" "test_txt" {
  for_each = { for item in(flatten([
    for domain, records in var.domain_records : [
      for record in records : merge(record, { "domain" : domain })
    ]
    ])) : "${item.domain}_${item.name}" => item
  }
  type   = each.value.type
  data   = each.value.data
  name   = each.value.name
  domain = maas_dns_domain.domains[each.value.domain].id
}

# 8
# Setup commissioning scripts
resource "maas_node_script" "node_scripts" {
  for_each = var.node_scripts

  script = base64encode(file("${var.node_scripts_location}/${each.value}"))
}
