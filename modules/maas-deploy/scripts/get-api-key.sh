#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

# Extract "model" and "username" arguments from the input into
# MODEL and USERNAME shell variables.
# jq will ensure that the values are properly quoted
# and escaped for consumption by the shell.
eval "$(jq -r '@sh "MODEL=\(.model) USERNAME=\(.username)"')"

get_key_cmd=$(juju run -m $MODEL maas-region/leader get-api-key username=$USERNAME --no-color --quiet --format json | jq -r '. | to_entries[].value.results')

# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted
# and escaped to produce a valid JSON string.
if [ "$( jq 'has("api-key")' <<< $get_key_cmd )" == "true" ]; then
    jq -n --arg key "$(echo $get_key_cmd | jq -r '.["api-key"]')" '{"api_key":$key}'
    exit 0
else
    >&2 echo "could not retrieve API key"
    exit 1
fi
