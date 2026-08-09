source "amazon-ebs" "app" {
  region        = var.aws_region
  instance_type = "t4g.small"
  ssh_username  = "ubuntu"
  ami_name      = "${var.project_name}-app-{{timestamp}}"

  source_ami_filter {
    most_recent = true
    owners      = ["099720109477"]
    filters = {
      architecture        = "arm64"
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
  }

  tags = {
    Name      = "${var.project_name}-app-image"
    ManagedBy = "Packer"
    Role      = "streamlit-web"
  }
}

build {
  name    = "app"
  sources = ["source.amazon-ebs.app"]

  provisioner "ansible" {
    playbook_file = "../ansible/playbook.yml"
    extra_arguments = [
      "--extra-vars",
      "local_ai_assistant_service_role=streamlit local_ai_assistant_ollama_version=${var.ollama_version}",
    ]
  }
}
