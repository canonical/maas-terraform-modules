#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

# Extract "model" argument from the input into
# MODEL shell variable.
# jq will ensure that the values are properly quoted
# and escaped for consumption by the shell.
eval "$(jq -r '@sh "MODEL=\(.model)"')"

get_url_cmd=$(juju run -m $MODEL maas-region/leader get-api-endpoint --no-color --quiet --format json | jq -r '. | to_entries[].value.results')

# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted
# and escaped to produce a valid JSON string.
if [ "$( jq 'has("api-url")' <<< $get_url_cmd )" == "true" ]; then
    jq -n --arg url "$(echo $get_url_cmd | jq -r '.["api-url"]')" '{"api_url":$url}'
    exit 0
else
    >&2 echo "could not retrieve API URL"
    exit 1
fi
