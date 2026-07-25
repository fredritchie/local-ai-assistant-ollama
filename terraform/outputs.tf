output "instance_id" {
  description = "ID of the GPU EC2 instance."
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "Public IPv4 address of the instance."
  value       = aws_instance.app.public_ip
}

output "streamlit_url" {
  description = "URL for the Streamlit application."
  value       = "http://${aws_instance.app.public_ip}:8501"
}

output "ssh_command" {
  description = "Example SSH command for the Ubuntu DLAMI."
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ubuntu@${aws_instance.app.public_ip}"
}

output "private_key_path" {
  description = "Local path to the Terraform-generated SSH private key."
  value       = local_sensitive_file.private_key.filename
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
