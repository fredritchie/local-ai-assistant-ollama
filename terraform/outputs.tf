output "instance_id" {
  description = "ID of the GPU EC2 instance."
  value       = aws_instance.app.id
}

output "aws_region" {
  description = "AWS region containing the deployment."
  value       = var.aws_region
}

output "public_ip" {
  description = "Public IPv4 address of the instance."
  value       = aws_instance.app.public_ip
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
  description = "Command that waits for bootstrap and application readiness."
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
    app_repository_version   = coalesce(var.repository_commit, "")
    app_deployment_mode      = var.deployment_mode
    ollama_version           = var.ollama_version
    ollama_primary_model     = var.ollama_model
    ollama_additional_models = var.additional_ollama_models
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
  description = "AWS Systems Manager Session Manager command for shell access."
  value       = "aws ssm start-session --region ap-south-1 --target ${aws_instance.app.id}"
}

output "vpc_id" {
  description = "ID of the newly created VPC."
  value       = aws_vpc.main.id
}

output "security_group_id" {
  description = "ID of the EC2 security group."
  value       = aws_security_group.app.id
}

output "selected_dlami_id" {
  description = "Latest GPU DLAMI selected through the AWS public SSM parameter."
  value       = data.aws_ssm_parameter.gpu_dlami.value
  sensitive   = true
}
