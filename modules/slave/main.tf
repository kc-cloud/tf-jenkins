provider aws {
  alias       = "password_provider"
  region      = "us-west-2"
}

data aws_secretsmanager_secret_version ssh_cert {
  secret_id = "jenkins-slave-ssh-cert"
  provider = aws.password_provider
}

data aws_secretsmanager_secret_version user_credential {
  secret_id = "jenkins-admin"
  provider = aws.password_provider
}

locals {
  CW_LOG_GROUP_NAME = "/${var.stack_name}/ec2/nodes"
  jenkins_username = jsondecode(data.aws_secretsmanager_secret_version.user_credential.secret_string)["jenkins-admin-user"]
  jenkins_password = jsondecode(data.aws_secretsmanager_secret_version.user_credential.secret_string)["jenkins-admin-password"]
}

data template_cloudinit_config agent_user_data {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.root}/files/bootscript.sh", {
      STACK_NAME    = var.stack_name
    })
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/files/jenkins-slave.sh", {
      server_ip   = var.master_url,
      ssh_cert  = data.aws_secretsmanager_secret_version.ssh_cert.secret_string,
      jenkins_username = local.jenkins_username,
      jenkins_password = local.jenkins_password,
      cred_id          = var.cred_id
    })
  }
}

resource aws_cloudwatch_log_group jenkins_node {
  name              = local.CW_LOG_GROUP_NAME
  retention_in_days = 90
}

resource aws_ssm_parameter jenkins_node_cloudwatch_agent_config {
  name  = "AmazonCloudWatch-${var.stack_name}-parameter"
  type  = "String"
  value = templatefile("${path.root}/files/cloudwatch-agent-config.json", {
    CW_LOG_GROUP_NAME = aws_cloudwatch_log_group.jenkins_node.name,
  })
  description = "Cloudwatch agent configuration for jenkins nodes"
}

resource aws_launch_configuration jenkins_agent {
  name_prefix                 = var.stack_name
  image_id                    = var.ami_id
  instance_type               = var.instance_type
  iam_instance_profile        = var.instance_profile_name
  security_groups             = [aws_security_group.jenkins_slave.id]
  user_data                   = data.template_cloudinit_config.agent_user_data.rendered
  associate_public_ip_address = false

  root_block_device {
    delete_on_termination = true
    volume_size = 100
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource aws_autoscaling_group jenkins_worker_linux {
  name                      = "dev-jenkins-worker-linux"
  min_size                  = 0
  max_size                  = var.max_size
  desired_capacity          = var.desired_size
  health_check_grace_period = 60
  health_check_type         = "EC2"
  vpc_zone_identifier       = var.private_subnet_ids
  launch_configuration      = aws_launch_configuration.jenkins_agent.name
  termination_policies      = [ "OldestLaunchConfiguration" ]
  wait_for_capacity_timeout = "10m"
  default_cooldown          = 60

  tags = [
    {
      key                 = "Name"
      value               = var.stack_name
      propagate_at_launch = true
    },
    {
      key                 = "project"
      value               = var.project_code
      propagate_at_launch = true
    },
    {
      key                 = "cost-code"
      value               = var.cost_code
      propagate_at_launch = true
    },
  ]
}