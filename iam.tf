resource aws_iam_instance_profile instance_profile {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.instance_role.name
}

resource aws_iam_role instance_role {
  name               = "${var.name}-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
    }]
  })

  inline_policy {
    name = "policy-to-fetch-secrets"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [ "secretsmanager:GetSecretValue", "secretsmanager:ListSecrets"]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = ["kms:Decrypt"]
          Effect   = "Allow"
          Resource = "*"
          Condition = {
            StringEquals = {
              "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
            }
          }
        }
      ]
    })
  }

  inline_policy {
    name = "policy-to-access-s3-backup"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
          Action   = [ "s3:*" ]
          Effect   = "Allow"
          Resource = [
            "arn:aws:s3:::${module.s3backup.backup_bucket_name}",
            "arn:aws:s3:::${module.s3backup.backup_bucket_name}/*"
          ]
      }]
    })
  }

  inline_policy {
    name = "policy-to-assume-job-role"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
          Action   = [ "sts:AssumeRole" ]
          Effect   = "Allow"
          Resource = [
            "arn:aws:iam:::role/${local.stack_name}-job-execution-role"
          ]
      }]
    })
  }

  inline_policy {
    name = "ec2-and-ssm-permissions"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
          Action   = [ "ssm:*", "ec2:Describe*", "ec2:CreateTags" ]
          Effect   = "Allow"
          Resource = ["*"]
      }]
    })
  }
}