#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 HEALTH_URL" >&2
  exit 2
fi

health_url=$1
timeout_seconds=${WAIT_TIMEOUT_SECONDS:-3600}
deadline=$((SECONDS + timeout_seconds))

while ((SECONDS < deadline)); do
  if curl --fail --silent --show-error --max-time 10 "$health_url" >/dev/null; then
    printf 'Application is healthy: %s\n' "$health_url"
    exit 0
  fi
  sleep 15
done

echo "Application did not become healthy within ${timeout_seconds} seconds" >&2
exit 1
