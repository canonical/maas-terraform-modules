# How to enroll rack controllers

Charmed MAAS manages controllers in region and region+rack mode as part of the control plane infrastructure. Standalone rack controllers are not part of the charmed deployment and must be enrolled manually. This guide covers how to register a rack controller with your Charmed MAAS deployment, including important considerations for HA and TLS-enabled environments for setups requiring network forwarding (see [Expose MAAS API externally on LXD](./how_to_expose_maas_api_externally_on_lxd.md)).

## Prerequisites

- A running Charmed MAAS deployment.
- A machine to use as the rack controller, with MAAS installed, and with network access to the region controllers.

## Get the cluster secret

Retrieve the MAAS cluster secret from the `maas-region` charm by running the following Juju action:

```bash
juju run maas-region/leader get-maas-secret
```

For more details, see the [get-maas-secret action documentation](https://charmhub.io/maas-region/actions#get-maas-secret).

## Determine the MAAS URL

The MAAS URL used for rack controller registration should point to the MAAS API URL. Obtain it with:

```bash
juju run maas-region/leader get-api-endpoint
```

> [!IMPORTANT]
> When MAAS serves the API over TLS, `get-api-endpoint` will output an `https` URL. For later steps, use the same host and path outputted in that URL, but set the scheme to `http`. Rack-to-region communication for enrollment requires `HTTP`, not `HTTPS`. For HA deployments, this URL should be the HAProxy endpoint but on port 80.

For clouds where a LXD network forward has been set up to expose the MAAS API, you should use the LXD network forward IP (or its DNS record) instead, for example:

```
http://maas.internal/MAAS
```

> [!IMPORTANT]
> The hostname for the MAAS API URL must be resolvable and reachable by the rack controller to be registered over the network.

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
