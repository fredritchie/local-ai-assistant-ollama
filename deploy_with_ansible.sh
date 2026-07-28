#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
INVENTORY_FILE="$ANSIBLE_DIR/inventory.terraform.ini"
KNOWN_HOSTS_FILE="$ANSIBLE_DIR/known_hosts.terraform"
KNOWN_HOSTS_TEMP="$ANSIBLE_DIR/known_hosts.terraform.tmp"

usage() {
    echo "Usage: ./deploy_with_ansible.sh [terraform apply options]"
    echo
    echo "Examples:"
    echo "  ./deploy_with_ansible.sh"
    echo "  ./deploy_with_ansible.sh -auto-approve"
    echo
    echo "Set allowed_app_cidr and allowed_ssh_cidr in"
    echo "terraform/terraform.tfvars before deploying."
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Required command not found: $command_name" >&2
        exit 1
    fi
}

resolve_terraform_path() {
    local terraform_path="$1"

    if [[ "$terraform_path" == /* ]]; then
        printf '%s\n' "$terraform_path"
    else
        printf '%s\n' "$TERRAFORM_DIR/${terraform_path#./}"
    fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

require_command terraform
require_command ansible
require_command ansible-playbook
require_command ssh-keyscan

echo "Initializing Terraform..."
terraform -chdir="$TERRAFORM_DIR" init -input=false

echo "Creating the VM and network resources..."
terraform -chdir="$TERRAFORM_DIR" apply \
    "$@" \
    -var="server_configuration=ansible" \
    -var="enable_ssh=true"

if [[ "$(terraform -chdir="$TERRAFORM_DIR" output -raw server_configuration)" != "ansible" ]]; then
    echo "Terraform did not select Ansible server configuration." >&2
    exit 1
fi

PUBLIC_IP="$(terraform -chdir="$TERRAFORM_DIR" output -raw public_ip)"
PRIVATE_KEY_OUTPUT="$(
    terraform -chdir="$TERRAFORM_DIR" output -raw private_key_path
)"
PRIVATE_KEY_PATH="$(resolve_terraform_path "$PRIVATE_KEY_OUTPUT")"
ANSIBLE_VARIABLES="$(
    terraform -chdir="$TERRAFORM_DIR" output -json ansible_variables
)"

if [[ ! -f "$PRIVATE_KEY_PATH" ]]; then
    echo "Terraform SSH key was not found at $PRIVATE_KEY_PATH." >&2
    exit 1
fi

chmod 0600 "$PRIVATE_KEY_PATH"

echo "Waiting for SSH on $PUBLIC_IP..."
SSH_KEY_FOUND=false
for _ in {1..60}; do
    if ssh-keyscan -T 5 -H "$PUBLIC_IP" >"$KNOWN_HOSTS_TEMP" 2>/dev/null &&
        [[ -s "$KNOWN_HOSTS_TEMP" ]]; then
        mv "$KNOWN_HOSTS_TEMP" "$KNOWN_HOSTS_FILE"
        SSH_KEY_FOUND=true
        break
    fi
    sleep 10
done

if [[ "$SSH_KEY_FOUND" != "true" ]]; then
    echo "SSH did not become available on $PUBLIC_IP within 10 minutes." >&2
    exit 1
fi

chmod 0600 "$KNOWN_HOSTS_FILE"

{
    echo "[app_servers]"
    printf '%s\n' \
        "local-ai-assistant ansible_host=$PUBLIC_IP ansible_user=ubuntu ansible_ssh_private_key_file='$PRIVATE_KEY_PATH' ansible_ssh_common_args='-o UserKnownHostsFile=$KNOWN_HOSTS_FILE -o StrictHostKeyChecking=yes'"
} >"$INVENTORY_FILE"
chmod 0600 "$INVENTORY_FILE"

echo "Configuring $PUBLIC_IP with Ansible..."
(
    cd "$ANSIBLE_DIR"
    ansible app_servers \
        -i "$INVENTORY_FILE" \
        -m ansible.builtin.wait_for_connection \
        -a "timeout=600 sleep=10"
    ansible-playbook \
        -i "$INVENTORY_FILE" \
        playbook.yml \
        --extra-vars "$ANSIBLE_VARIABLES"
)

STREAMLIT_URL="$(terraform -chdir="$TERRAFORM_DIR" output -raw streamlit_url)"
echo "Deployment complete: $STREAMLIT_URL"
