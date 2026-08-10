mock_provider "aws" {}

override_data {
  target = data.aws_ec2_instance_type_offerings.gpu
  values = {
    locations = ["ap-south-1a", "ap-south-1b"]
  }
}

override_data {
  target = data.aws_ssm_parameter.ubuntu_amd64
  values = { value = "ami-00000000000000001" }
}

override_data {
  target = data.aws_ssm_parameter.ubuntu_arm64
  values = { value = "ami-00000000000000002" }
}

override_data {
  target = data.aws_ssm_parameter.gpu_dlami
  values = { value = "ami-00000000000000003" }
}

override_data {
  target = data.aws_caller_identity.current
  values = { account_id = "123456789012" }
}

override_data {
  target = data.aws_iam_policy_document.workload_kms
  values = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
}

override_data {
  target = data.aws_iam_policy_document.ec2_assume
  values = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
}

override_data {
  target = data.aws_iam_policy_document.app
  values = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
}

override_data {
  target = data.aws_iam_policy_document.gpu
  values = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
}

override_data {
  target = data.aws_iam_policy_document.alb_logs
  values = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
}

override_data {
  target = data.aws_iam_policy_document.flow_logs_assume
  values = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
}

override_data {
  target = data.aws_iam_policy_document.flow_logs
  values = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
}

run "production_high_availability" {
  command = plan

  variables {
    environment       = "prod"
    app_image_uri     = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/local-ai-assistant@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    enable_duckdns    = true
    duckdns_subdomain = "local-ai-portfolio"
    model_manifest = [
      {
        name     = "llama3.2:3b"
        digest   = "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        preload  = true
        size_gib = 2
        vram_gib = 4
      }
    ]
  }

  assert {
    condition     = aws_autoscaling_group.app.min_size == 2
    error_message = "Production must keep at least two application instances."
  }

  assert {
    condition     = aws_autoscaling_group.gpu.desired_capacity == 2
    error_message = "The production default must provide redundant GPU capacity."
  }

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.app) == 2 && length(aws_subnet.gpu) == 2
    error_message = "Every network tier must span two Availability Zones."
  }

  assert {
    condition     = aws_lb.ollama.internal
    error_message = "Ollama must remain behind an internal load balancer."
  }

  assert {
    condition     = length(aws_globalaccelerator_accelerator.public) == 1 && output.duckdns_fqdn == "local-ai-portfolio.duckdns.org"
    error_message = "DuckDNS mode must create the stable accelerator entry point and hostname output."
  }
}
