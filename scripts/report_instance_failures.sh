#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 AUTO_SCALING_GROUP_NAME" >&2
  exit 2
fi

group_name=$1
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$group_name" \
  --query 'AutoScalingGroups[0].Instances[].InstanceId' \
  --output text | tr '\t' '\n' | while read -r instance_id; do
  [[ -n "$instance_id" ]] || continue
  printf 'Instance %s\n' "$instance_id"
  aws ssm send-command \
    --instance-ids "$instance_id" \
    --document-name AWS-RunShellScript \
    --parameters 'commands=["cloud-init status --long || true","test -f /var/lib/local-ai/bootstrap-complete && echo bootstrap-complete || true","test -f /var/lib/local-ai/bootstrap-failed && echo bootstrap-failed || true","tail -n 100 /var/log/local-ai-bootstrap.log"]' \
    --query 'Command.CommandId' --output text
done
