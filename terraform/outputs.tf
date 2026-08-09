output "instance_id" {
  description = "Compatibility alias for the Streamlit EC2 instance."
  value       = aws_instance.app.id
}

output "app_instance_id" {
  description = "ID of the public Streamlit EC2 instance."
  value       = aws_instance.app.id
}

output "ollama_instance_id" {
  description = "ID of the private Ollama GPU EC2 instance."
  value       = aws_instance.ollama.id
}

output "aws_region" {
  description = "AWS region containing the deployment."
  value       = var.aws_region
}

output "public_ip" {
  description = "Public IPv4 address of the Streamlit instance."
  value       = aws_instance.app.public_ip
}

output "ollama_private_ip" {
  description = "Private IPv4 address of the Ollama instance."
  value       = aws_instance.ollama.private_ip
}

output "streamlit_url" {
  description = "URL for the Streamlit application."
  value       = "http://${aws_instance.app.public_ip}:8501"
}

output "application_health_check_command" {
  description = "Command that checks the public Streamlit health endpoint."
  value       = "curl --fail --show-error http://${aws_instance.app.public_ip}:8501/_stcore/health"
}

output "wait_for_application_command" {
  description = "Command that waits for both services and application readiness."
  value       = "./wait_for_application.sh"
}

output "deployment_mode" {
  description = "Configured application runtime mode."
  value       = var.deployment_mode
}

output "server_configuration" {
  description = "System responsible for configuring the EC2 instance."
  value       = var.server_configuration
}

output "ansible_variables" {
  description = "Application variables consumed by the Ansible deployment wrapper."
  value = {
    app_repository_url       = var.repository_url
    app_repository_branch    = var.repository_branch
    app_repository_version   = var.repository_commit != null ? var.repository_commit : ""
    app_deployment_mode      = var.deployment_mode
    ollama_version           = var.ollama_version
    ollama_primary_model     = var.ollama_model
    ollama_additional_models = var.additional_ollama_models
    ollama_private_url       = "http://${aws_instance.ollama.private_ip}:11434"
  }
}

output "ssh_command" {
  description = "Example SSH command when optional SSH access is enabled."
  value       = var.enable_ssh ? "ssh -i ${local_sensitive_file.private_key[0].filename} ubuntu@${aws_instance.app.public_ip}" : null
}

output "private_key_path" {
  description = "Local path to the generated key when SSH is enabled."
  value       = var.enable_ssh ? local_sensitive_file.private_key[0].filename : null
}

output "ssm_session_command" {
  description = "Session Manager command for the Streamlit instance."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.app.id}"
}

output "ollama_ssm_session_command" {
  description = "Session Manager command for the private Ollama instance."
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.ollama.id}"
}

output "vpc_id" {
  description = "ID of the newly created VPC."
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "ID of the Streamlit security group."
  value       = aws_security_group.app.id
}

output "ollama_security_group_id" {
  description = "ID of the private Ollama security group."
  value       = aws_security_group.ollama.id
}

output "selected_app_ami_id" {
  description = "Ubuntu AMI selected for the Streamlit instance architecture."
  value       = local.app_ami_id
  sensitive   = true
}

output "selected_dlami_id" {
  description = "GPU DLAMI selected for the private Ollama instance."
  value       = data.aws_ssm_parameter.gpu_dlami.value
  sensitive   = true
}
