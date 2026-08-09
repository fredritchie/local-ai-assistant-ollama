terraform {
  backend "s3" {
    key          = "local-ai-assistant/prod/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
