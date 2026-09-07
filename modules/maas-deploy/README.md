# MAAS deploy module

This OpenTofu/Terraform module creates a Juju model, deploys the MAAS region and PostgreSQL charms, and configures them.

Input modes:

- Managed model mode: leave `model_uuid = null` and provide `juju_cloud_name` and `lxd_project` (`juju_cloud_region` defaults to `default`). The module creates and manages the Juju model.
- Existing model mode: set `model_uuid` to an existing Juju model UUID. In this mode, model-creation inputs (`juju_cloud_name`, `juju_cloud_region`, `lxd_project`) are ignored; the module emits a warning if `juju_cloud_name` or `lxd_project` are set.

See the [root README](../../README.md) for an architectural overview of this infrastructure pattern.
