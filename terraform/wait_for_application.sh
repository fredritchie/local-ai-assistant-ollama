#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TIMEOUT_SECONDS="${1:-3600}"
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
    command -v "$command" >/dev/null 2>&1 || {
        echo "Required command not found: $command" >&2
        exit 1
    }
done

APP_INSTANCE_ID="$(terraform output -raw app_instance_id)"
OLLAMA_INSTANCE_ID="$(terraform output -raw ollama_instance_id)"
AWS_REGION="$(terraform output -raw aws_region)"
APPLICATION_URL="$(terraform output -raw streamlit_url)"
HEALTH_URL="$APPLICATION_URL/_stcore/health"
STARTED_AT="$(date +%s)"
NEXT_CONSOLE_CHECK=0
APP_BOOTSTRAP_COMPLETE=false
OLLAMA_BOOTSTRAP_COMPLETE=false

console_output() {
    aws ec2 get-console-output \
        --region "$AWS_REGION" \
        --instance-id "$1" \
        --latest \
        --query Output \
        --output text 2>/dev/null || true
}

report_failure() {
    local service="$1"
    local output="$2"
    echo "$service bootstrap reported a failure:" >&2
    printf '%s\n' "$output" | tail -n 100 >&2
    echo "Use the corresponding Terraform Session Manager output for diagnostics." >&2
    exit 1
}

echo "Waiting up to $TIMEOUT_SECONDS seconds for Ollama and Streamlit readiness."

while true; do
    if [[ "$APP_BOOTSTRAP_COMPLETE" == "true" &&
        "$OLLAMA_BOOTSTRAP_COMPLETE" == "true" ]] && \
        curl --fail --silent --show-error --max-time 5 "$HEALTH_URL" >/dev/null 2>&1; then
        ELAPSED_SECONDS="$(($(date +%s) - STARTED_AT))"
        echo "Both services are ready after $ELAPSED_SECONDS seconds."
        echo "$APPLICATION_URL"
        exit 0
    fi

    NOW="$(date +%s)"
    ELAPSED_SECONDS="$((NOW - STARTED_AT))"
    ((ELAPSED_SECONDS >= TIMEOUT_SECONDS)) && break

    if ((ELAPSED_SECONDS >= NEXT_CONSOLE_CHECK)); then
        OLLAMA_CONSOLE="$(console_output "$OLLAMA_INSTANCE_ID")"
        APP_CONSOLE="$(console_output "$APP_INSTANCE_ID")"

        [[ "$OLLAMA_CONSOLE" == *"OLLAMA_BOOTSTRAP_FAILED"* ]] && \
            report_failure "Ollama" "$OLLAMA_CONSOLE"
        [[ "$APP_CONSOLE" == *"STREAMLIT_BOOTSTRAP_FAILED"* ]] && \
            report_failure "Streamlit" "$APP_CONSOLE"

        [[ "$OLLAMA_CONSOLE" == *"OLLAMA_BOOTSTRAP_COMPLETE"* ]] && \
            OLLAMA_BOOTSTRAP_COMPLETE=true
        [[ "$APP_CONSOLE" == *"STREAMLIT_BOOTSTRAP_COMPLETE"* ]] && \
            APP_BOOTSTRAP_COMPLETE=true

        echo "Still waiting (${ELAPSED_SECONDS}s): Streamlit=$APP_BOOTSTRAP_COMPLETE Ollama=$OLLAMA_BOOTSTRAP_COMPLETE"
        NEXT_CONSOLE_CHECK="$((ELAPSED_SECONDS + 30))"
    fi

    sleep "$POLL_SECONDS"
done

echo "Timed out waiting for the microservices." >&2
echo "Streamlit diagnostics:" >&2
echo "  $(terraform output -raw ssm_session_command)" >&2
echo "  sudo cat /var/lib/local-ai-assistant/bootstrap-failed" >&2
echo "  sudo journalctl -u local-ai-assistant -n 100 --no-pager" >&2
echo "Ollama diagnostics:" >&2
echo "  $(terraform output -raw ollama_ssm_session_command)" >&2
echo "  sudo cat /var/lib/local-ai-assistant-ollama/bootstrap-failed" >&2
echo "  sudo journalctl -u ollama -n 100 --no-pager" >&2
exit 1
