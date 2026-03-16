# How to configure a LXD cloud for Juju bootstrap

This document outlines how to configure your LXD backing cloud to create the inputs required for the `juju-bootstrap` unit and the stacks. If running the stacks or units for the first time, you should follow these instructions first.

## Prerequisites

See the prerequisites in the root [README](../../README.md).

## Getting started

1. Ensure your cloud is exposed to the network. See [the LXD documentation](https://documentation.ubuntu.com/lxd/latest/howto/server_expose/) for more information.
    ```bash
    lxc config set core.https_address :8443
    ```
    As described in the docs, find an available address to use to connect to your cloud.

1. Create a trust token for your LXD server/cluster

    ```bash
    lxc config trust add --name maas-charms
    ```
    You can view created tokens with:
    ```bash
    lxc config trust list-tokens
    ```

    > [!NOTE]
    > In production settings, you may want to limit the scope of the trust token to specifc projects, and/or make it restricted:
    > ```bash
    > lxc config trust add --name maas-charms --projects "default,myproject" --restricted
    > ```
    > See the LXD documentation for more information on trust token options.

1. Optionally, create a new LXD project to isolate cluster resources from preexisting resources. It is recommended to copy the default profile, and modify if needed.

    ```bash
    lxc project create maas-charms
    lxc profile copy default default --target-project maas-charms --refresh
    ```

1. Add the address, trust token, and any other options to the relevant stack/unit file you'd like to deploy. See the `examples/` directory for more information.

## Next steps

- See the [examples/stacks](../../examples/stacks/README.md) directory to start deploying using the provided stacks.
