# Terraform deployment guide

## 1. Bootstrap durable artifacts

The state bucket must exist before an environment can initialize its backend.
Bootstrap therefore begins with local state:

```bash
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap apply \
  -var='state_bucket_name=YOUR-GLOBALLY-UNIQUE-BUCKET'
```

Store and protect the bootstrap state immediately. You may migrate it to its own
S3 key after the bucket exists. The S3 bucket uses versioning, KMS encryption,
public-access blocking, TLS enforcement, and `prevent_destroy`.

Environment backends use `use_lockfile = true`. DynamoDB locking is not created
because HashiCorp has deprecated it. See the [S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3).

## 2. Lock the model manifest

Replace the example all-zero digest with output from:

```bash
python scripts/lock_model_manifest.py \
  --model llama3.2:3b:2.0:4.0:true \
  > models/model-manifest.json
```

Update `model_manifest_file` in your variable file.

## 3. Build and push the application image

```bash
repository=$(terraform -chdir=terraform/bootstrap output -raw ecr_repository_url)
export IMAGE_URI=$(./scripts/build_and_push.sh "$repository")
```

## 4. Initialize an environment

```bash
cp terraform/environments/dev/terraform.tfvars.example \
  terraform/environments/dev/terraform.tfvars

terraform -chdir=terraform/environments/dev init \
  -backend-config="bucket=YOUR-STATE-BUCKET" \
  -backend-config="kms_key_id=YOUR-STATE-KMS-KEY-ARN"
```

Update the CIDRs, model manifest path, certificate, alarm address, AMIs, and
snapshot settings as required.

## 5. Plan and apply

```bash
terraform -chdir=terraform/environments/dev plan \
  -var="app_image_uri=$IMAGE_URI"

IMAGE_URI="$IMAGE_URI" \
STATE_BUCKET="YOUR-STATE-BUCKET" \
STATE_KMS_KEY_ID="YOUR-STATE-KMS-KEY-ARN" \
./scripts/deploy.sh dev
```

Promote the same digest to production only after development smoke tests.

## Environment isolation

Development and production use separate root modules, state keys, CIDRs,
capacity, NAT strategy, retention, and deletion protection. For stricter
organizational isolation, place them in separate AWS accounts and assume
environment-specific deployment roles.

## Validation without deployment

```bash
terraform fmt -check -recursive terraform
terraform -chdir=terraform/bootstrap init -backend=false
terraform -chdir=terraform/bootstrap validate
terraform -chdir=terraform/environments/dev init -backend=false
terraform -chdir=terraform/environments/dev validate
terraform -chdir=terraform/modules/platform init -backend=false
terraform -chdir=terraform/modules/platform test
```
