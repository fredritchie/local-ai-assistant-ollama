#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 ECR_REPOSITORY_URL" >&2
  exit 2
fi

repository_url=$1
region=$(cut -d. -f4 <<<"$repository_url")
registry=${repository_url%%/*}
revision=${GITHUB_SHA:-$(git rev-parse HEAD)}
tag="sha-${revision}"

aws ecr get-login-password --region "$region" |
  docker login --username AWS --password-stdin "$registry" >&2

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --provenance=true \
  --sbom=true \
  --tag "${repository_url}:${tag}" \
  --push . >&2

digest=$(aws ecr describe-images \
  --region "$region" \
  --repository-name "${repository_url#*/}" \
  --image-ids "imageTag=${tag}" \
  --query 'imageDetails[0].imageDigest' \
  --output text)

if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "ECR did not return a valid image digest" >&2
  exit 1
fi

printf '%s@%s\n' "$repository_url" "$digest"
