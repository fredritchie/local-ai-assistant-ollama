#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TIMEOUT_SECONDS="${1:-1800}"
POLL_SECONDS="${POLL_SECONDS:-10}"

if [[ ! "$TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Usage: $0 [positive-timeout-seconds]" >&2
    exit 2
fi

if [[ ! "$POLL_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
    echo "POLL_SECONDS must be a positive integer." >&2
    exit 2
fi

for command in aws curl terraform; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Required command not found: $command" >&2
        exit 1
    fi
done

INSTANCE_ID="$(terraform output -raw instance_id)"
AWS_REGION="$(terraform output -raw aws_region)"
APPLICATION_URL="$(terraform output -raw streamlit_url)"
HEALTH_URL="$APPLICATION_URL/_stcore/health"
STARTED_AT="$(date +%s)"
NEXT_CONSOLE_CHECK=0
LAST_CONSOLE_OUTPUT=""

echo "Waiting up to $TIMEOUT_SECONDS seconds for $HEALTH_URL"

while true; do
    if curl \
        --fail \
        --silent \
        --show-error \
        --max-time 5 \
        "$HEALTH_URL" >/dev/null 2>&1; then
        ELAPSED_SECONDS="$(($(date +%s) - STARTED_AT))"
        echo "Application is healthy after $ELAPSED_SECONDS seconds."
        echo "$APPLICATION_URL"
        exit 0
    fi

    NOW="$(date +%s)"
    ELAPSED_SECONDS="$((NOW - STARTED_AT))"

    if ((ELAPSED_SECONDS >= TIMEOUT_SECONDS)); then
        break
    fi

    if ((ELAPSED_SECONDS >= NEXT_CONSOLE_CHECK)); then
        LAST_CONSOLE_OUTPUT="$(
            aws ec2 get-console-output \
                --region "$AWS_REGION" \
                --instance-id "$INSTANCE_ID" \
                --latest \
                --query Output \
                --output text 2>/dev/null || true
        )"

        if [[ "$LAST_CONSOLE_OUTPUT" == *"LOCAL_AI_BOOTSTRAP_FAILED"* ]]; then
            echo "EC2 bootstrap reported a failure:" >&2
            printf '%s\n' "$LAST_CONSOLE_OUTPUT" | tail -n 80 >&2
            echo >&2
            echo "Connect with Session Manager, then run:" >&2
            echo "  sudo cat /var/lib/local-ai-assistant/bootstrap-failed" >&2
            echo "  sudo tail -n 200 /var/log/cloud-init-output.log" >&2
            exit 1
        fi

        echo "Still waiting (${ELAPSED_SECONDS}s elapsed)..."
        NEXT_CONSOLE_CHECK="$((ELAPSED_SECONDS + 30))"
    fi

    sleep "$POLL_SECONDS"
done

echo "Timed out waiting for the application health endpoint." >&2

if [[ -n "$LAST_CONSOLE_OUTPUT" && "$LAST_CONSOLE_OUTPUT" != "None" ]]; then
    echo "Latest EC2 console output:" >&2
    printf '%s\n' "$LAST_CONSOLE_OUTPUT" | tail -n 80 >&2
fi

echo >&2
echo "Connect with Session Manager and run:" >&2
echo "  sudo cloud-init status --long" >&2
echo "  sudo cat /var/lib/local-ai-assistant/bootstrap-complete" >&2
echo "  sudo cat /var/lib/local-ai-assistant/bootstrap-failed" >&2
echo "  sudo local-ai-assistant-health" >&2
echo "  sudo journalctl -u local-ai-assistant -n 100 --no-pager" >&2
exit 1
