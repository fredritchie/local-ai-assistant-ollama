# Ansible image configuration

The Ansible role prepares immutable application and GPU machine images. Packer
invokes the role while building AMIs; production instances are not configured
manually after an Auto Scaling Group launches them.

The `streamlit` image installs Docker, Nginx, AWS CLI, and supporting packages.
The `ollama` image installs XFS tools and the pinned Ollama release. Terraform
launch-template user data supplies environment-specific runtime configuration,
the ECR image digest, model manifest, logging, and health registration.

## Prerequisites and ownership

Use Python 3, Ansible, and `ansible-lint` from `requirements-dev.txt`. The
playbook uses built-in modules and does not require a separate Galaxy role or
collection installation. Packer supplies a temporary build host; AWS
credentials and the build region are therefore Packer concerns.

Keep common operating-system packages and stable host configuration in this
role. Keep environment-specific values—ECR digest, RDS endpoint, IAM database
authentication settings, model manifest, CloudWatch log groups, and load
balancer registration—in Terraform launch-template user data. Never bake
environment secrets into an AMI.

## Local syntax check

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
ansible-playbook -i ansible/inventory.ini.example \
  ansible/playbook.yml --syntax-check
ansible-lint ansible/playbook.yml
```

Run `ansible --version` and `ansible-lint --version` when reproducing CI. The
repository's pinned CI environment is authoritative; see
[the CI workflow](../.github/workflows/ci.yml).

Do not run the image playbook against an existing production instance. Build a
new AMI, update the Terraform AMI variable, and use an Auto Scaling instance
refresh instead.

See [the Packer guide](../packer/README.md) for the supported AMI build
commands and how to record their output in Terraform inputs.
