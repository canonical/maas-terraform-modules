#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

# Extract "model", "juju_controller_address", "juju_username", and "juju_password" arguments from the input into
# MODEL, JUJU_CONTROLLER_ADDRESS, JUJU_USERNAME, and JUJU_PASSWORD shell variables.
# jq will ensure that the values are properly quoted
# and escaped for consumption by the shell.
eval "$(jq -r '@sh "MODEL=\(.model) JUJU_CONTROLLER_ADDRESS=\(.juju_controller_address) JUJU_USERNAME=\(.juju_username) JUJU_PASSWORD=\(.juju_password)"')"

# We need to set JUJU_DATA to a unique directory to avoid conflicts with other juju commands that might be running in parallel,
# since juju CLI uses a shared state directory by default ($HOME/.local/share/juju).
# Link: https://documentation.ubuntu.com/juju/3.6/reference/juju-cli/juju-environment-variables/#juju-data
# We also need to execute the juju binary from the path /snap/juju/current/bin/juju to allow Juju to access JUJU_DATA in the /tmp directory.
# This is needed since snap packages are using /tmp/snap-private-tmp/snap.<snap-name>/tmp for their temporary files.
# If we execute the binary by simply calling "juju", Juju will create the JUJU_DATA directory in the snap's temporary directory, and we won't
# be able to delete it after running the command, which will cause conflicts with other juju commands that might be running in parallel.

# Login to Juju
export JUJU_DATA=/tmp/juju-$(openssl rand -hex 4)
echo "$JUJU_PASSWORD" | /snap/juju/current/bin/juju login -c maas-controller "$JUJU_CONTROLLER_ADDRESS" -u "$JUJU_USERNAME" --trust --no-prompt

get_url_cmd=$(/snap/juju/current/bin/juju run -m $MODEL maas-region/leader get-api-endpoint --no-color --quiet --format json | jq -r '. | to_entries[].value.results')

# Delete local Juju data to logout and clean up any cached credentials
rm -rf $JUJU_DATA

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
