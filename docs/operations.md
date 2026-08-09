# Operations and recovery

## Deployment health

```bash
terraform -chdir=terraform/environments/prod output -raw application_health_url
./scripts/wait_for_application.sh "https://your-host/healthz"
./scripts/smoke_test.sh "https://your-host"
```

Open the dashboard named by:

```bash
terraform -chdir=terraform/environments/prod output -raw dashboard_name
```

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

Production ALB deletion protection prevents accidental destruction. To remove
production, submit a reviewed change setting `enable_deletion_protection` to
false, apply it, archive and empty the ALB access-log bucket, then destroy.
Development log objects are deleted with the development stack. Bootstrap state
and ECR resources are protected separately and should not be casually destroyed.
