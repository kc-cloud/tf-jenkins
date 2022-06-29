
provider aws {
  region      = "us-east-1"
}

data aws_secretsmanager_secret_version ssh_key {
  secret_id = "jenkins-slave-ssh-key"
}

data aws_secretsmanager_secret_version user_credential {
  secret_id = "jenkins-admin"
}

locals {
  CW_LOG_GROUP_NAME = "/${var.stack_name}/ec2/nodes"
  jenkins_username = jsondecode(data.aws_secretsmanager_secret_version.user_credential.secret_string)["jenkins-admin-user"]
  jenkins_password = jsondecode(data.aws_secretsmanager_secret_version.user_credential.secret_string)["jenkins-admin-password"]
}

data aws_secretsmanager_secret_version key {
  secret_id = "arn:aws:secretsmanager:us-east-1:1234569:secret:tls-key"
}

data aws_secretsmanager_secret_version cert {
  secret_id = "arn:aws:secretsmanager:us-east-1:1234569:secret:tls-certificate"
}

resource aws_iam_server_certificate alb_cert {
  name_prefix      = "jenkins-cert"
  certificate_body = data.aws_secretsmanager_secret_version.cert.secret_string
  private_key      = data.aws_secretsmanager_secret_version.key.secret_string
  lifecycle {
    create_before_destroy = true
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
      content_type = "text/cloud-config"
      content = jsonencode({
        write_files = [{
            content = templatefile("${path.module}/files/create-node-credentials.groovy", {
              ssh_key = data.aws_secretsmanager_secret_version.ssh_key.secret_string,
              cred_id = var.cred_id
            })
            path    = "/build-artifacts/create-node-credentials.groovy"
          }]
      })
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/files/jenkins-server.sh", {
      jenkins_admin_password = local.jenkins_password,
      backup_bucket_name     = var.backup_bucket_name
    })
  }
}

resource aws_launch_configuration lc {
  name_prefix   = "jenkins"
  image_id      = var.ami_id
  instance_type = var.instance_type
  lifecycle {
    create_before_destroy = true
  }
  security_groups       = [ aws_security_group.jenkins_server.id ]
  iam_instance_profile  = var.instance_profile_name
  user_data             = data.template_cloudinit_config.agent_user_data.rendered

  root_block_device {
    volume_type = "gp3"
    volume_size = "20"
    encrypted = true
    delete_on_termination = true
  }
}

resource aws_autoscaling_group asg {
  depends_on = [ aws_launch_configuration.lc ]
  name          = "${var.stack_name}-asg"
  launch_configuration = aws_launch_configuration.lc.name
  vpc_zone_identifier   = var.private_subnet_ids
  min_size              = 0
  max_size             = 1
  desired_capacity     = 1
  health_check_grace_period = 300
  health_check_type    = "EC2"
  target_group_arns = [ aws_lb_target_group.alb_tg.arn ]

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

  lifecycle {
    create_before_destroy = true
  }
}