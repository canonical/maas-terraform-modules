# How to enroll rack controllers

Charmed MAAS manages controllers in region and region+rack mode as part of the control plane infrastructure. Standalone rack controllers are not part of the charmed deployment and must be enrolled manually. This guide covers how to register a rack controller with your Charmed MAAS deployment, including important considerations for HA and TLS-enabled environments for setups requiring network forwarding (see [Expose MAAS API externally on LXD](./how_to_expose_maas_api_externally_on_lxd.md)).

## Prerequisites

- A running Charmed MAAS deployment.
- A machine to use as the rack controller, with maas installed, and with network access to the region controllers.

## Get the cluster secret

Retrieve the MAAS cluster secret from the `maas-region` charm by running the following Juju action:

```bash
juju run maas-region/leader get-maas-secret
```

For more details, see the [get-maas-secret action documentation](https://charmhub.io/maas-region/actions#get-maas-secret).

## Determine the MAAS URL

The MAAS URL used for rack controller registration should point to the MAAS API URL. This can be obtained with:

```bash
juju run maas-region/leader get-api-endpoint
```

For clouds where a LXD network forward has been setup, you should use the LXD network forward IP (or its DNS record), for example:

```
http://maas.internal/MAAS
```

> [!IMPORTANT]
> - For HA deployments, the URL should target the HAProxy endpoint on port 80.
> - Do **not** use `https`, even if MAAS TLS is enabled. The rack to region communication requires HTTP.

## Register the rack controller

On the machine you want to enroll as a rack controller, run:

```bash
sudo maas init rack --maas-url http://maas.internal/MAAS --secret <cluster-secret>
```

Replace `<cluster-secret>` and the `maas-url` with the values obtained in the previous steps.

For full details on adding a rack controller, see the [MAAS HA documentation](https://canonical.com/maas/docs/how-to-manage-high-availability#p-9026-enable-ha-for-rack-controllers).

## Network considerations

Rack controllers must be able to reach the region controllers over a separate network to establish RPC connections. They will not be able to access the OVN internal network IPs of the region controllers directly.

Ensure that the rack controller machine has network connectivity to the region controllers on a network that is routable from outside the OVN network connecting the regions.
