lxd_project = "maas-system"
charm_postgresql_config = {
  experimental_max_connections = 100
  plugin_btree_gin_enable      = true
}
charm_maas_region_channel = "3.7/edge"
charm_maas_region_config = {
  enable_rack_mode = true
}
pxe_subnet_cidr = "10.0.2.1/24"
