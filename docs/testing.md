# Testing strategy

## Fast CI checks

- Ruff and Pytest with coverage
- Docker image build and live Streamlit health check
- Terraform formatting and validation for bootstrap, dev, and prod
- Terraform native test with a mocked AWS provider
- TFLint and Checkov
- Ansible syntax and ansible-lint
- Packer formatting and syntax validation
- ShellCheck for operational and launch-template scripts
- Trivy filesystem and dependency scan

Run the core local checks after installing Python 3.12, Terraform, Docker,
Ansible, and the packages in `requirements-dev.txt`:

```bash
python -m pip install -r requirements-dev.txt
ruff check .
pytest -m "not integration"
terraform fmt -check -recursive terraform
terraform -chdir=terraform/modules/platform test
ansible-playbook -i ansible/inventory.ini.example \
  ansible/playbook.yml --syntax-check
```

The remaining CI checks need additional tools or pinned GitHub Actions. Install
them locally only when you need to reproduce that part of CI:

```bash
tflint --init
tflint --recursive --config "$(pwd)/.tflint.hcl"
shellcheck scripts/*.sh
./scripts/check_user_data.sh
packer init packer
packer fmt -check -recursive packer
packer validate -syntax-only packer
checkov --config-file .checkov.yml --directory terraform --framework terraform
trivy fs --scanners vuln,secret --severity HIGH,CRITICAL .
```

GitHub Actions is the source of truth for pinned tool versions and security
scan configuration; see [CI](../.github/workflows/ci.yml).

## Deployed integration tests

Integration tests are opt-in because they require billable AWS resources:

```bash
export INTEGRATION_BASE_URL="http://your-alb-name.ap-south-1.elb.amazonaws.com"
pytest -m integration -v
```

The `Deployed integration tests` workflow accepts the same URL and runs both
shell and Pytest smoke tests.

## Database IAM bootstrap smoke test

After a controlled `deploy`, confirm the database bootstrap CodeBuild job
succeeded before testing chat persistence:

```bash
aws logs tail /local-ai-assistant/ENVIRONMENT/database-bootstrap --follow
```

From an application instance reached with Session Manager, verify the app can
generate an IAM token and initialize its schema:

```bash
docker exec local-ai-assistant python -c \
  'from database import initialize_database; initialize_database(); print("IAM database connection succeeded")'
```

This is an opt-in deployed check: it requires the private database path and the
application instance role. Do not run the RDS IAM-user bootstrap script from
the application instance.

## Failure testing

For a controlled non-production exercise:

1. Confirm the development app ASG has two healthy targets temporarily.
2. Terminate one app instance through EC2.
3. Verify ALB health remains green and ASG creates a replacement.
4. Confirm the replacement completion marker and dashboard telemetry.
5. Repeat for GPU only when two GPU targets are running and cost is approved.

Do not automate instance termination in ordinary CI. Failure injection is a
separate, explicitly approved infrastructure test.
