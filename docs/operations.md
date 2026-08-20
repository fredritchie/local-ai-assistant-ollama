# Operations and recovery

This runbook covers health verification, alerting, diagnostics, database
authentication, rollback, capacity changes, certificate operations, and
controlled teardown.

> **Documentation:** [Index](README.md)
> · [All architecture diagrams](diagrams/README.md)
> · [Deployment guide](deployment-guide.md)

## Architecture context

### Telemetry and operational visibility

![Observability and monitoring architecture](diagrams/observability_monitoring_architecture.png)

## Deployment health

```bash
health_url=$(terraform -chdir=terraform/environments/prod \
  output -raw application_health_url)
application_url=$(terraform -chdir=terraform/environments/prod \
  output -raw application_url)
./scripts/wait_for_application.sh "$health_url"
./scripts/smoke_test.sh "$application_url"
```

Open the dashboard named by:

```bash
terraform -chdir=terraform/environments/prod output -raw dashboard_name
```

## Health-check email alerts

The public application target group checks `GET /healthz` every 15 seconds.
After three failed checks, CloudWatch raises the `app-unhealthy` alarm (after
three one-minute alarm periods). The internal Ollama target group is monitored
in the same way by the `gpu-unhealthy` alarm. Both alarm and recovery events
are published to the environment's SNS alarm topic.

Set `alarm_email` in the environment `terraform.tfvars` before applying, then
confirm the SNS subscription message that AWS emails to that address. Verify
the configured topic with:

```bash
terraform -chdir=terraform/environments/prod output -raw health_alert_topic_arn
```

Without confirmation, AWS does not deliver alert emails.

## Instance access

Find instances by ASG or tag and start a Session Manager session:

```bash
aws ec2 describe-instances \
  --filters Name=tag:Environment,Values=prod Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Role`].Value|[0]]' \
  --output table

aws ssm start-session --target INSTANCE_ID
```

There is no SSH key or port 22 rule.

## Load balancer and application diagnostics

When an application URL times out, first check the public target group in
**EC2 → Target Groups → Targets**. A healthy EC2 instance must be registered
on port 80 and pass `GET /healthz`; an unhealthy target is not an IAM database
failure.

For instance bootstrap and application logs, use the environment-specific
CloudWatch groups:

```bash
aws logs tail /local-ai-assistant/ENVIRONMENT/app --follow
aws logs tail /local-ai-assistant/ENVIRONMENT/bootstrap --follow
aws logs tail /local-ai-assistant/ENVIRONMENT/database-bootstrap --follow
```

Replace `ENVIRONMENT` with `dev` or `prod`. The database-bootstrap log belongs
to CodeBuild; the app EC2 role is intentionally not permitted to start it or
read the RDS administrator secret.

## RDS IAM authentication diagnostics

Use Session Manager to reach an application instance, then run:

```bash
docker exec local-ai-assistant python -c \
  'from database import initialize_database; initialize_database(); print("IAM database connection succeeded")'
```

`connection timeout expired` indicates VPC routing, NACL, or security-group
reachability. `password authentication failed for user "localai_app"` usually
means the database bootstrap job has not granted `rds_iam` yet. In that case,
rerun the controlled deployment or start the CodeBuild project from an
administrator/deployment identity; do not grant RDS administrator permissions
to the application role.

## Bootstrap failure reporting

```bash
./scripts/report_instance_failures.sh APP_AUTO_SCALING_GROUP_NAME
```

The script submits an SSM command for cloud-init status, completion/failure
markers, and the last bootstrap log lines. Retrieve the returned command IDs
with `aws ssm get-command-invocation`.

On an instance:

```bash
cloud-init status --long
test -f /var/lib/local-ai/bootstrap-complete
test -f /var/lib/local-ai/bootstrap-failed
sudo tail -n 200 /var/log/local-ai-bootstrap.log
```

## Application rollback

1. Select a previously scanned ECR digest.
2. Set `app_image_uri` to that exact digest.
3. Review and apply the Terraform plan.
4. Terraform updates the launch template and starts a rolling instance refresh.
5. Confirm target health and application smoke tests.

Do not retag an image as `latest`; ECR tag immutability intentionally prevents
that workflow.

## HTTPS certificate operations

Imported Let's Encrypt certificates are renewed by the monthly
`Renew DuckDNS Let's Encrypt certificate` workflow. Check the active
certificate and the public endpoint with:

```bash
aws acm describe-certificate \
  --region ap-south-1 \
  --certificate-arn "$ACM_CERTIFICATE_ARN" \
  --query 'Certificate.[DomainName,Status,NotAfter]' \
  --output table

openssl s_client \
  -connect "${DUCKDNS_SUBDOMAIN}.duckdns.org:443" \
  -servername "${DUCKDNS_SUBDOMAIN}.duckdns.org" </dev/null
```

If renewal fails, run the protected workflow manually and inspect its logs.
The CloudWatch certificate-expiry alarm warns when fewer than 30 days remain.
See the [deployment guide](deployment-guide.md#optional-duckdns-and-tls-lifecycle)
for certificate setup, renewal, and recovery procedures.

## Host rollback

Restore the previous `app_ami_id` or `gpu_ami_id`, plan, and apply. ASG
auto-rollback is enabled for failed instance refreshes, but operators must still
review target health and alarms.

## Scaling

Application scaling is automatic within its configured minimum and maximum.
Change GPU desired capacity only after confirming:

- EC2 On-Demand G-family quota
- `g4dn.xlarge` availability in both selected AZs
- model snapshot readiness
- estimated monthly cost
- model VRAM and concurrency behavior

## Destruction

Use **GitHub → Actions → Controlled deployment** for normal teardown: select
`operation=destroy`, set `confirm_destroy=DESTROY`, supply the deployed image
digest, and approve the selected environment. The workflow temporarily disables
production deletion protection with a targeted Terraform operation on only the
RDS instance and two load balancers; it does not reconcile the whole
configuration before creating its destroy plan. It also permits removal of the
ALB log bucket. Development log objects are deleted with the
environment. Bootstrap state and ECR resources are protected separately and
should not be casually destroyed.

## Implementation references

- Monitoring source: [`observability.tf`](../terraform/modules/platform/observability.tf)
  and [`logging.tf`](../terraform/modules/platform/logging.tf)
- Recovery tooling: [`wait_for_application.sh`](../scripts/wait_for_application.sh),
  [`report_instance_failures.sh`](../scripts/report_instance_failures.sh), and
  [`smoke_test.sh`](../scripts/smoke_test.sh)
