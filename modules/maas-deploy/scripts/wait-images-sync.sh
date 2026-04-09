#!/bin/bash

set -euo pipefail

api_url="${MAAS_API_URL%/}"
api_key="${MAAS_API_KEY}"
timeout_seconds="${TIMEOUT_SECONDS}"
poll_interval_seconds="${POLL_INTERVAL_SECONDS}"

IFS=':' read -r consumer_key token secret <<< "${api_key}"

start_time="$(date +%s)"
endpoint="${api_url}/api/2.0/boot-resources/?op=is_importing"

while true; do
  auth_header="Authorization: OAuth oauth_version=\"1.0\", oauth_signature_method=\"PLAINTEXT\", oauth_consumer_key=\"${consumer_key}\", oauth_token=\"${token}\", oauth_signature=\"&${secret}\", oauth_nonce=\"$(uuidgen)\", oauth_timestamp=\"$(date +%s)\""

  is_importing="$(curl --fail --silent --show-error --header "${auth_header}" "${endpoint}")"

  if [[ "${is_importing}" == "false" ]]; then
    echo "MAAS image import complete."
    exit 0
  fi

  elapsed="$(( $(date +%s) - start_time ))"
  if [[ "${elapsed}" -ge "${timeout_seconds}" ]]; then
    echo "Timed out waiting for MAAS image import after ${timeout_seconds}s." >&2
    exit 1
  fi

  echo "MAAS image import in progress (is_importing=${is_importing}, elapsed=${elapsed}s)"
  sleep "${poll_interval_seconds}"
done
