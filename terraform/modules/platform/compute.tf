#checkov:skip=CKV_AWS_341:Hop limit 2 is required for the non-root host-network container to retrieve temporary role credentials.
resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-app-"
  image_id      = local.app_ami_id
  instance_type = var.app_instance_type
  user_data = base64encode(templatefile("${path.module}/templates/app_user_data.sh.tftpl", {
    app_image_uri       = var.app_image_uri
    aws_region          = var.aws_region
    parameter_prefix    = local.parameter_prefix
    secret_arns         = join(",", local.app_secret_arns)
    app_log_group       = aws_cloudwatch_log_group.app.name
    nginx_log_group     = aws_cloudwatch_log_group.nginx.name
    bootstrap_log_group = aws_cloudwatch_log_group.bootstrap.name
  }))

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      encrypted             = true
      delete_on_termination = true
      volume_size           = var.app_root_volume_size
      volume_type           = "gp3"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups             = [aws_security_group.app.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-app"
      Role = "streamlit-web"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-app"
      Role = "streamlit-web"
    })
  }

  update_default_version = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "gpu" {
  name_prefix   = "${local.name_prefix}-gpu-"
  image_id      = local.gpu_ami_id
  instance_type = var.gpu_instance_type
  user_data = base64encode(templatefile("${path.module}/templates/gpu_user_data.sh.tftpl", {
    aws_region               = var.aws_region
    ollama_version           = var.ollama_version
    model_manifest_parameter = aws_ssm_parameter.model_manifest.name
    ollama_log_group         = aws_cloudwatch_log_group.ollama.name
    bootstrap_log_group      = aws_cloudwatch_log_group.bootstrap.name
  }))

  iam_instance_profile {
    arn = aws_iam_instance_profile.gpu.arn
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      encrypted             = true
      delete_on_termination = true
      volume_size           = var.gpu_root_volume_size
      volume_type           = "gp3"
    }
  }

  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      encrypted             = true
      delete_on_termination = true
      snapshot_id           = var.model_snapshot_id
      volume_size           = var.model_volume_size
      volume_type           = "gp3"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups             = [aws_security_group.gpu.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-gpu"
      Role = "ollama-inference"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-gpu"
      Role = "ollama-inference"
    })
  }

  update_default_version = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  name_prefix = "${local.name_prefix}-app-"

  min_size                  = var.app_capacity.min
  desired_capacity          = var.app_capacity.desired
  max_size                  = var.app_capacity.max
  health_check_type         = "ELB"
  health_check_grace_period = 900
  vpc_zone_identifier       = aws_subnet.app[*].id
  target_group_arns         = [aws_lb_target_group.app.arn]
  default_cooldown          = 120
  capacity_rebalance        = true
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupPendingCapacity",
    "GroupTotalCapacity",
  ]

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      auto_rollback          = true
      instance_warmup        = 180
      min_healthy_percentage = 50
      skip_matching          = true
    }
    triggers = ["tag"]
  }

  dynamic "tag" {
    for_each = merge(local.common_tags, {
      Name = "${local.name_prefix}-app"
      Role = "streamlit-web"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_route_table_association.app,
    aws_iam_role_policy.app,
  ]
}

resource "aws_autoscaling_policy" "app_cpu" {
  name                   = "${local.name_prefix}-app-cpu"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = 60
    disable_scale_in = false
  }
}

resource "aws_autoscaling_group" "gpu" {
  name_prefix = "${local.name_prefix}-gpu-"

  min_size                  = var.gpu_capacity.min
  desired_capacity          = var.gpu_capacity.desired
  max_size                  = var.gpu_capacity.max
  health_check_type         = "ELB"
  health_check_grace_period = 3600
  vpc_zone_identifier       = aws_subnet.gpu[*].id
  target_group_arns         = [aws_lb_target_group.ollama.arn]
  default_cooldown          = 600
  capacity_rebalance        = true
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupPendingCapacity",
    "GroupTotalCapacity",
  ]

  launch_template {
    id      = aws_launch_template.gpu.id
    version = aws_launch_template.gpu.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      auto_rollback          = true
      instance_warmup        = 1800
      min_healthy_percentage = var.gpu_capacity.desired > 1 ? 50 : 0
      skip_matching          = true
    }
    triggers = ["tag"]
  }

  dynamic "tag" {
    for_each = merge(local.common_tags, {
      Name = "${local.name_prefix}-gpu"
      Role = "ollama-inference"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_route_table_association.gpu,
    aws_iam_role_policy.gpu,
    aws_ssm_parameter.model_manifest,
  ]
}
