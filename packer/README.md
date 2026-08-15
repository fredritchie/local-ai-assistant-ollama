# Immutable AMIs with Packer and Ansible

Packer builds reusable application and GPU host images. This reduces launch
time and prevents ASG replacement instances from depending entirely on package
installation at boot.

> **Documentation:** [Index](../docs/README.md)
> · [All architecture diagrams](../docs/diagrams/README.md)
> · [Deployment guide](../docs/deployment-guide.md)

## Architecture context

### App and GPU AMI pipelines

![Packer and Ansible AMI build architecture](../docs/diagrams/packer_ansible_ami_build_architecture.png)

## Configuration ownership

Packer creates temporary build hosts and invokes
[`ansible/playbook.yml`](../ansible/playbook.yml). The `streamlit` image installs
Docker, Nginx, AWS CLI, and supporting packages. The `ollama` image installs
XFS tools and the pinned Ollama release.

Keep stable operating-system packages and common host configuration in the
Ansible role. Keep environment-specific values—ECR digest, RDS endpoint, IAM
database settings, model manifest, CloudWatch log groups, and target health
behavior—in Terraform launch-template user data. Never bake environment
secrets into an AMI, and never run the image playbook directly against an
existing production instance.

## Build and release procedure

Before building, authenticate the AWS CLI or export credentials for the target
account, select the intended region (the examples use `ap-south-1`), and ensure
your identity can create and clean up Packer build instances, volumes, security
groups, key pairs, and AMIs. Packer invokes the repository's Ansible role.

```bash
packer init packer
packer fmt -check -recursive packer
packer validate -syntax-only packer
packer build -only=app.amazon-ebs.app packer
```

Resolve the current GPU DLAMI from AWS SSM before building the GPU image:

```bash
gpu_ami=$(aws ssm get-parameter \
  --region ap-south-1 \
  --name /aws/service/deeplearning/ami/x86_64/base-with-single-cuda-ubuntu-24.04/latest/ami-id \
  --query Parameter.Value --output text)

packer build -only=gpu.amazon-ebs.gpu \
  -var="gpu_source_ami=$gpu_ami" packer
```

Record each resulting AMI ID in the appropriate
`terraform/environments/<environment>/terraform.tfvars` file as `app_ami_id`
or `gpu_ami_id`, review the Terraform plan, and roll instances through the
controlled deployment workflow.

The SSM `latest` lookup is appropriate only to select a candidate DLAMI. Record
and review the resolved AMI ID before using it in a repeatable build or release;
do not treat an unreviewed future `latest` value as an immutable artifact.

Packer builds are billable and should run in a controlled build subnet/account
where possible. Preserve the Packer build log and AMI IDs with the release
record so a host-image rollback is reproducible.

## Validation

Install the pinned development requirements, then validate both the Packer and
Ansible layers:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
ansible-playbook -i ansible/inventory.ini.example \
  ansible/playbook.yml --syntax-check
ansible-lint ansible/playbook.yml
packer init packer
packer fmt -check -recursive packer
packer validate -syntax-only packer
```

The pinned [CI workflow](../.github/workflows/ci.yml) remains authoritative for
tool versions and validation behavior.

## Implementation references

- [`app.pkr.hcl`](app.pkr.hcl) selects the latest matching Canonical Ubuntu
  source for the application build.
- [`gpu.pkr.hcl`](gpu.pkr.hcl) consumes the explicitly supplied GPU source AMI.
- [`playbook.yml`](../ansible/playbook.yml) applies the shared host role during
  both builds.
- [`roles/local_ai_assistant/tasks/main.yml`](../ansible/roles/local_ai_assistant/tasks/main.yml)
  defines baked host configuration.
- [`app_user_data.sh.tftpl`](../terraform/modules/platform/templates/app_user_data.sh.tftpl)
  and [`gpu_user_data.sh.tftpl`](../terraform/modules/platform/templates/gpu_user_data.sh.tftpl)
  define environment-specific launch behavior.
