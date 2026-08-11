#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF' >&2
Usage: scripts/bootstrap_rds_iam_user.sh --db-instance-id ID [options]

Options:
  --region REGION       AWS Region (default: AWS_REGION or ap-south-1)
  --username USER       PostgreSQL IAM user (default: localai_app)

Run this from an administrator-controlled host that can reach the private RDS
endpoint and can read the RDS managed master secret. It does not persist the
master password or grant the application EC2 role access to that secret.
EOF
  exit 2
}

db_instance_id=""
region="${AWS_REGION:-ap-south-1}"
app_username="localai_app"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-instance-id) db_instance_id="${2:-}"; shift 2 ;;
    --region) region="${2:-}"; shift 2 ;;
    --username) app_username="${2:-}"; shift 2 ;;
    --help|-h) usage ;;
    *) usage ;;
  esac
done

[[ -n "$db_instance_id" && -n "$app_username" ]] || usage

for command in aws jq psql; do
  command -v "$command" >/dev/null || {
    echo "Required command is not installed: $command" >&2
    exit 1
  }
done

db_json=$(aws rds describe-db-instances \
  --db-instance-identifier "$db_instance_id" \
  --region "$region" \
  --query 'DBInstances[0].{host:Endpoint.Address,port:Endpoint.Port,name:DBName,secret:MasterUserSecret.SecretArn,status:DBInstanceStatus}' \
  --output json)

db_status=$(jq -r '.status' <<<"$db_json")
db_host=$(jq -r '.host' <<<"$db_json")
db_port=$(jq -r '.port' <<<"$db_json")
db_name=$(jq -r '.name' <<<"$db_json")
secret_arn=$(jq -r '.secret' <<<"$db_json")

if [[ "$db_status" != "available" ]]; then
  echo "RDS instance must be available; current status: $db_status" >&2
  exit 1
fi

if [[ "$db_host" == "null" || "$db_name" == "null" || "$secret_arn" == "null" ]]; then
  echo "RDS endpoint, database name, or managed master secret is unavailable." >&2
  exit 1
fi

secret=$(aws secretsmanager get-secret-value \
  --secret-id "$secret_arn" \
  --region "$region" \
  --query SecretString \
  --output text)

master_username=$(jq -r '.username' <<<"$secret")
export PGPASSWORD
PGPASSWORD=$(jq -r '.password' <<<"$secret")
trap 'unset PGPASSWORD' EXIT

psql "host=$db_host port=$db_port dbname=$db_name user=$master_username sslmode=require" \
  --set=ON_ERROR_STOP=1 \
  --set=db_name="$db_name" \
  --set=app_username="$app_username" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN', :'app_username')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_username')
\gexec

GRANT rds_iam TO :"app_username";
GRANT CONNECT ON DATABASE :"db_name" TO :"app_username";
GRANT USAGE, CREATE ON SCHEMA public TO :"app_username";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO :"app_username";
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO :"app_username";
SQL

echo "Configured PostgreSQL IAM user '$app_username' on '$db_instance_id'."
