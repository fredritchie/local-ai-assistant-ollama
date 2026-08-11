# Immutable AMIs with Packer and Ansible

Packer builds reusable application and GPU host images. This reduces launch
time and prevents ASG replacement instances from depending entirely on package
installation at boot.

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
