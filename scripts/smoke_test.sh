#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 APPLICATION_URL" >&2
  exit 2
fi

base_url=${1%/}
curl --fail --silent --show-error --max-time 15 "$base_url/healthz" >/dev/null
curl --fail --silent --show-error --max-time 15 "$base_url/" |
  grep --ignore-case --quiet "streamlit"
printf 'Smoke tests passed for %s\n' "$base_url"
