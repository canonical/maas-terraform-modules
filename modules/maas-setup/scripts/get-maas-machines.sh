#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

# Extract "model" and "machine_ids" arguments from the input into
# MODEL and MACHINE_IDS shell variables.
# jq will ensure that the values are properly quoted
# and escaped for consumption by the shell.
eval "$(jq -r '@sh "MODEL=\(.model) MACHINE_IDS=\(.machine_ids)"')"

hostnames=""
for i in $MACHINE_IDS; do
    hostname=$(juju machines -m $MODEL --quiet --format=json | jq -r --argjson i $i '.machines | to_entries[$i].value.hostname')
    if [ -z "$hostnames" ]; then
        hostnames="$hostname"
    else
        hostnames="$hostnames,$hostname"
    fi
done

# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted
# and escaped to produce a valid JSON string.
jq -n --arg machines $hostnames '{"machines":$machines}'
