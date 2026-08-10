#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^(dev|prod)$ ]]; then
  echo "Usage: IMAGE_URI=... STATE_BUCKET=... $0 dev|prod" >&2
  exit 2
fi

: "${IMAGE_URI:?Set IMAGE_URI to an immutable ECR URI with @sha256 digest}"
: "${STATE_BUCKET:?Set STATE_BUCKET to the bootstrap S3 bucket}"

environment=$1
terraform_dir="terraform/environments/${environment}"

backend_args=(-backend-config="bucket=${STATE_BUCKET}")
if [[ -n "${STATE_KMS_KEY_ID:-}" ]]; then
  backend_args+=(-backend-config="kms_key_id=${STATE_KMS_KEY_ID}")
fi

terraform -chdir="$terraform_dir" init -reconfigure "${backend_args[@]}"
terraform -chdir="$terraform_dir" fmt -check
terraform -chdir="$terraform_dir" validate
terraform -chdir="$terraform_dir" plan \
  -input=false \
  -out=tfplan \
  -var="app_image_uri=${IMAGE_URI}"
terraform -chdir="$terraform_dir" apply tfplan

health_url=$(terraform -chdir="$terraform_dir" output -raw application_health_url)
"$(dirname "$0")/wait_for_application.sh" "$health_url"
