#!/usr/bin/env bash
set -Eeuo pipefail

render_dir=$(mktemp -d /tmp/local-ai-user-data.XXXXXX)
trap 'rm -rf -- "$render_dir"' EXIT

for template in terraform/modules/platform/templates/*.sh.tftpl; do
  rendered="$render_dir/$(basename "$template" .tftpl)"
  # Literal Terraform placeholders must remain single-quoted for replacement.
  # shellcheck disable=SC2016
  sed \
    -e 's/\$\$/\$/g' \
    -e 's/${ollama_version}/0.32.0/g' \
    -e 's/${aws_region}/ap-south-1/g' \
    -e 's#${model_manifest_parameter}#/example/manifest#g' \
    -e 's#${app_image_uri}#123.dkr.ecr.ap-south-1.amazonaws.com/app@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa#g' \
    -e 's#${parameter_prefix}#/example#g' \
    -e 's/${secret_arns}//g' \
    -e 's#${bootstrap_log_group}#/bootstrap#g' \
    -e 's#${nginx_log_group}#/nginx#g' \
    -e 's#${app_log_group}#/app#g' \
    -e 's#${ollama_log_group}#/ollama#g' \
    "$template" >"$rendered"
  bash -n "$rendered"
  shellcheck "$rendered"
done
