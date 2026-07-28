data "aws_ec2_instance_type_offerings" "gpu" {
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }

  location_type = "availability-zone"
}

data "aws_ssm_parameter" "gpu_dlami" {
  name = "/aws/service/deeplearning/ami/x86_64/base-with-single-cuda-ubuntu-24.04/latest/ami-id"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = sort(tolist(data.aws_ec2_instance_type_offerings.gpu.locations))[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet"
    Environment = var.environment
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-routes"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "app" {
  name_prefix = "${var.project_name}-"
  description = "Restricts Streamlit and optional SSH access to trusted CIDRs"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []

    content {
      description = "SSH from trusted address"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_blocks = [coalesce(var.allowed_ssh_cidr, "127.0.0.1/32")]
    }
  }

  ingress {
    description = "Streamlit from trusted address"
    protocol    = "tcp"
    from_port   = 8501
    to_port     = 8501
    cidr_blocks = [var.allowed_app_cidr]
  }

  egress {
    description = "Outbound access for packages, Git, and Ollama models"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = !var.enable_ssh || var.allowed_ssh_cidr != null
      error_message = "allowed_ssh_cidr must be set when enable_ssh is true."
    }
  }
}

resource "tls_private_key" "app" {
  count = var.enable_ssh ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "app" {
  count = var.enable_ssh ? 1 : 0

  key_name   = var.key_name
  public_key = trimspace(tls_private_key.app[0].public_key_openssh)

  tags = {
    Name        = var.key_name
    Environment = var.environment
  }
}

resource "local_sensitive_file" "private_key" {
  count = var.enable_ssh ? 1 : 0

  content              = tls_private_key.app[0].private_key_pem
  filename             = "${path.module}/${var.key_name}.pem"
  file_permission      = "0600"
  directory_permission = "0700"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name_prefix        = "${var.project_name}-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name        = "${var.project_name}-instance-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name_prefix = "${var.project_name}-"
  role        = aws_iam_role.app.name
}

resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.gpu_dlami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = var.enable_ssh ? aws_key_pair.app[0].key_name : null
  iam_instance_profile        = aws_iam_instance_profile.app.name
  associate_public_ip_address = true

  user_data = var.server_configuration == "cloud-init" ? templatefile(
    "${path.module}/user_data.sh.tftpl",
    {
      repository_url           = var.repository_url
      repository_branch        = var.repository_branch
      repository_commit        = coalesce(var.repository_commit, "")
      deployment_mode          = var.deployment_mode
      ollama_version           = var.ollama_version
      ollama_model             = var.ollama_model
      additional_ollama_models = join(" ", var.additional_ollama_models)
    }
  ) : null

  user_data_replace_on_change = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  lifecycle {
    precondition {
      condition     = var.server_configuration != "ansible" || var.enable_ssh
      error_message = "enable_ssh must be true when server_configuration is ansible."
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = self.tags["ForceDestroy"] == "true" ? "aws ec2 terminate-instances --region ap-south-1 --instance-ids ${self.id} --force --skip-os-shutdown --no-cli-pager" : "echo 'Graceful EC2 termination selected.'"
  }

  tags = {
    Name                = "${var.project_name}-gpu"
    Environment         = var.environment
    ServerConfiguration = var.server_configuration
    ForceDestroy        = tostring(var.force_destroy_skip_os_shutdown)
  }

  depends_on = [
    aws_route_table_association.public,
    aws_iam_role_policy_attachment.ssm,
    local_sensitive_file.private_key,
  ]
}
