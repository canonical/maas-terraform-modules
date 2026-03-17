#!/bin/bash
# usage: ./reserve-lxd-address.sh $NETWORK
set -euo pipefail

NETWORK=${1:-lxdbr0}

SUBNET=$(lxc network show "$NETWORK" | grep "ipv4.address" | awk '{print $2}')

USED=$(lxc network list-leases "$NETWORK" -f=json | jq -r '.[].address')

# it's easier to correctly parse the subnet range in python than mess around in bash
NEXT_IP=$(python3 <<EOF
import ipaddress, sys

subnet = ipaddress.ip_network("$SUBNET", strict=False)
used = set("""$USED""".split())

for ip in subnet.hosts():
    ip_str = str(ip)
    if ip_str not in used:
        print(ip_str)
        sys.exit(0)
sys.exit(1)
EOF
)

if [ -z "$NEXT_IP" ]; then
    echo "No available IPs" >&2
    exit 1
fi

NAME="vip-reservation-${NEXT_IP//./-}"
lxc init ubuntu:24.04 "$NAME" > /dev/null
lxc config device add "$NAME" eth0 nic \
    network="$NETWORK" \
    ipv4.address="$NEXT_IP" > /dev/null
echo "$NEXT_IP"
