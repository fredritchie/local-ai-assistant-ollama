source "amazon-ebs" "gpu" {
  region        = var.aws_region
  instance_type = "g4dn.xlarge"
  source_ami    = var.gpu_source_ami
  ssh_username  = "ubuntu"
  ami_name      = "${var.project_name}-gpu-{{timestamp}}"

  tags = {
    Name      = "${var.project_name}-gpu-image"
    ManagedBy = "Packer"
    Role      = "ollama-inference"
  }
}

build {
  name    = "gpu"
  sources = ["source.amazon-ebs.gpu"]

  provisioner "ansible" {
    playbook_file = "../ansible/playbook.yml"
    extra_arguments = [
      "--extra-vars",
      "local_ai_assistant_service_role=ollama local_ai_assistant_ollama_version=${var.ollama_version}",
    ]
  }
}
