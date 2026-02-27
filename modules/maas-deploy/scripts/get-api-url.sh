#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

# Extract "model", "juju_controller_address", "juju_username", and "juju_password" arguments from the input into
# MODEL, JUJU_CONTROLLER_ADDRESS, JUJU_USERNAME, and JUJU_PASSWORD shell variables.
# jq will ensure that the values are properly quoted
# and escaped for consumption by the shell.
eval "$(jq -r '@sh "MODEL=\(.model) JUJU_CONTROLLER_ADDRESS=\(.juju_controller_address) JUJU_USERNAME=\(.juju_username) JUJU_PASSWORD=\(.juju_password)"')"

# Login to Juju
export JUJU_DATA=/tmp/$(openssl rand -hex 4)
echo "$JUJU_PASSWORD" | juju login -c maas-controller "$JUJU_CONTROLLER_ADDRESS" -u "$JUJU_USERNAME" --trust --no-prompt

get_url_cmd=$(juju run -m $MODEL maas-region/leader get-api-endpoint --no-color --quiet --format json | jq -r '. | to_entries[].value.results')

# Logout of Juju
juju unregister maas-controller --no-prompt

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
