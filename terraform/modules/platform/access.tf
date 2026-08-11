#checkov:skip=CKV2_AWS_5: Attached to the EC2 Instance Connect Endpoint through security_group_ids.
resource "aws_security_group" "instance_connect_endpoint" {
  count = var.enable_instance_connect_endpoint ? 1 : 0

  name_prefix = "${local.name_prefix}-instance-connect-"
  description = "EC2 Instance Connect Endpoint for private instance administration"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-instance-connect"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "instance_connect_to_app" {
  count = var.enable_instance_connect_endpoint ? 1 : 0

  security_group_id            = aws_security_group.instance_connect_endpoint[0].id
  referenced_security_group_id = aws_security_group.app.id
  description                  = "SSH from the managed endpoint to application instances"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "instance_connect_to_gpu" {
  count = var.enable_instance_connect_endpoint ? 1 : 0

  security_group_id            = aws_security_group.instance_connect_endpoint[0].id
  referenced_security_group_id = aws_security_group.gpu.id
  description                  = "SSH from the managed endpoint to GPU instances"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

#checkov:skip=CKV_AWS_24: SSH is restricted to the EC2 Instance Connect Endpoint security group, not a public CIDR.
resource "aws_vpc_security_group_ingress_rule" "app_from_instance_connect" {
  count = var.enable_instance_connect_endpoint ? 1 : 0

  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.instance_connect_endpoint[0].id
  description                  = "SSH from the EC2 Instance Connect Endpoint"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

#checkov:skip=CKV_AWS_24: SSH is restricted to the EC2 Instance Connect Endpoint security group, not a public CIDR.
resource "aws_vpc_security_group_ingress_rule" "gpu_from_instance_connect" {
  count = var.enable_instance_connect_endpoint ? 1 : 0

  security_group_id            = aws_security_group.gpu.id
  referenced_security_group_id = aws_security_group.instance_connect_endpoint[0].id
  description                  = "SSH from the EC2 Instance Connect Endpoint"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

# The endpoint creates an AWS-managed ENI. Keeping it in Terraform state and
# referencing the subnet directly ensures the endpoint and ENI are deleted
# before Terraform attempts to destroy the subnet.
resource "aws_ec2_instance_connect_endpoint" "management" {
  count = var.enable_instance_connect_endpoint ? 1 : 0

  subnet_id          = aws_subnet.app[0].id
  security_group_ids = [aws_security_group.instance_connect_endpoint[0].id]
  preserve_client_ip = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-instance-connect"
  })

  depends_on = [
    aws_vpc_security_group_egress_rule.instance_connect_to_app,
    aws_vpc_security_group_egress_rule.instance_connect_to_gpu,
    aws_vpc_security_group_ingress_rule.app_from_instance_connect,
    aws_vpc_security_group_ingress_rule.gpu_from_instance_connect,
  ]

  timeouts {
    delete = "10m"
  }
}
