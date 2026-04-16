# How to expose MAAS API externally on LXD

This document describes how to expose the MAAS API externally when deploying on a LXD cloud when using a private internal network, for example an [OVN network](https://documentation.ubuntu.com/lxd/default/reference/network_ovn/). This common for deployments on MicroCloud.

If you are deploying on a LXD cloud with a private internal network, you will need to setup a network forward to access the MAAS API externally on the uplink network. This is because the MAAS API will only be accessible from within the private network by default, but you likely want to access the API from the uplink network as well. For cases where a virtual IP address is used to access MAAS, you will also need to reserve the VIP on your private network to ensure no other machines are assigned it. Follow this guide before running your `maas-deploy` unit if you want to ensure IP address reservation of a virtual IP address. 

### Reserve the VIP

If you are specifying a `virtual_ip` for MAAS in the `maas-deploy` unit, you must ensure that the IP is reserved in your LXD cloud. 

From LXD 5.21.5 onwards, you will be able to reserve an IP address using [`ipv4.dhcp.ranges`](https://documentation.ubuntu.com/lxd/default/reference/network_ovn/#network-ovn-network-conf:ipv4.dhcp.ranges). Until then, you will need to use the following work around to reserve an IP address in OVN. In the following example, the private (OVN) network is `10.176.2.0/24`, and the uplink network is `10.239.7.0/24`:

On your LXD cloud, create a new container that acts as a VIP holder:
```bash
lxc init --empty vip-holder
```

Create an interface on the container with your VIP address. This should be the same address as the `virtual_ip` you will specify in your `maas-deploy` configuration:
```bash
lxc config device add vip-holder eth0 nic network=ovn-network-name name=eth0 ipv4.address=10.176.2.100
```

### Setup network forward

To forward the MAAS API accessible at `10.176.2.100` from the private network to the uplink network, on your LXD cloud, run the following and specify the relevant uplink and private IP addresses and network name:
```bash
lxc network forward create ovn-network-name 10.239.7.100 target_address=10.176.2.100
```

You can now deploy your unit or stack, specifying your `virtual_ip` in the `maas-deploy` unit if required. 
