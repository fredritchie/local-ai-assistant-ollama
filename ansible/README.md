# Ansible image configuration

The Ansible role prepares immutable application and GPU machine images. Packer
invokes the role while building AMIs; production instances are not configured
manually after an Auto Scaling Group launches them.

The `streamlit` image installs Docker, Nginx, AWS CLI, and supporting packages.
The `ollama` image installs XFS tools and the pinned Ollama release. Terraform
launch-template user data supplies environment-specific runtime configuration,
the ECR image digest, model manifest, logging, and health registration.

## Local syntax check

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
ansible-playbook -i ansible/inventory.ini.example \
  ansible/playbook.yml --syntax-check
ansible-lint ansible/playbook.yml
```

Do not run the image playbook against an existing production instance. Build a
new AMI, update the Terraform AMI variable, and use an Auto Scaling instance
refresh instead.
