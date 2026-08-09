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

Run the main local checks:

```bash
python -m pip install -r requirements-dev.txt
ruff check .
pytest -m "not integration"
terraform fmt -check -recursive terraform
terraform -chdir=terraform/modules/platform test
ansible-playbook -i ansible/inventory.ini.example \
  ansible/playbook.yml --syntax-check
```

## Deployed integration tests

Integration tests are opt-in because they require billable AWS resources:

```bash
export INTEGRATION_BASE_URL="http://your-alb-name.ap-south-1.elb.amazonaws.com"
pytest -m integration -v
```

The `Deployed integration tests` workflow accepts the same URL and runs both
shell and Pytest smoke tests.

## Failure testing

For a controlled non-production exercise:

1. Confirm the development app ASG has two healthy targets temporarily.
2. Terminate one app instance through EC2.
3. Verify ALB health remains green and ASG creates a replacement.
4. Confirm the replacement completion marker and dashboard telemetry.
5. Repeat for GPU only when two GPU targets are running and cost is approved.

Do not automate instance termination in ordinary CI. Failure injection is a
separate, explicitly approved infrastructure test.
