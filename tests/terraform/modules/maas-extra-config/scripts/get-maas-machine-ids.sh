#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

# Extract "model" and "is_maas" arguments from the input into
# MODEL and IS_MAAS shell variables.
# jq will ensure that the values are properly quoted
# and escaped for consumption by the shell.
eval "$(jq -r '@sh "MODEL=\(.model) IS_MAAS=\(.is_maas)"')"

# Get the juju status
get_status_cmd=$(juju status -m "$MODEL" --format json)

# Extract machine IDs for Juju applications based on IS_MAAS
if [ "$IS_MAAS" = "true" ]; then
  get_machine_ids_cmd=$(echo "$get_status_cmd" | jq -r '.applications | to_entries[] | select(.value["charm-name"] == "maas-region") | .value.units | to_entries[] | .value.machine')
else
  get_machine_ids_cmd=$(echo "$get_status_cmd" | jq -r '.applications | to_entries[] | select(.value["charm-name"] != "maas-region") | .value.units | to_entries[] | .value.machine')
fi

machine_ids=""
for machine_id in $get_machine_ids_cmd; do
  if [ -z "$machine_ids" ]; then
    machine_ids="$machine_id"
  else
    machine_ids="$machine_ids,$machine_id"
  fi
done

# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted
# and escaped to produce a valid JSON string.
jq -n --arg machine_ids "$machine_ids" '{"machine_ids":$machine_ids}'
