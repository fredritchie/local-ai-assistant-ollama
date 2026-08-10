# Immutable AMIs with Packer and Ansible

Packer builds reusable application and GPU host images. This reduces launch
time and prevents ASG replacement instances from depending entirely on package
installation at boot.

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

Record the resulting AMI IDs in the environment variable file. Packer builds
are billable and should run in a controlled build subnet/account where
possible.
