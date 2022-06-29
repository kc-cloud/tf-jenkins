terraform {
  backend "s3" {}
}

provider aws {
  region = var.aws_region
}

data aws_caller_identity current {}

locals {
  master            = "${var.name}-master"
  slave             = "${var.name}-slave"
  stack_name        = "${var.project_name}-${var.environment}-${var.name}"
  cred_id           = "node-connection-secret"
  project_code      = "${var.project_name}-jenkins"
  cost_code         = "${var.project_name}-shared"
}

data aws_ami ubuntu {
  owners = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

module "s3backup" {
    source      = "./modules/backup"
    aws_region  = var.aws_region
    vpc_id      = var.vpc_id
    namespace   = var.namespace
    name        = var.name
    component_name = "backup"
    tags        = {
      "project-code"  = local.project_code
      "cost-code"     = local.cost_code
    }
}

module jenkins_master {
  source              = "./modules/master"
  aws_region          = var.aws_region
  vpc_id              = var.vpc_id
  public_subnet_ids   = var.public_subnet_ids
  private_subnet_ids  = var.private_subnet_ids
  private_subnet_cidrs= var.private_subnet_cidrs
  ami_id              = data.aws_ami.ubuntu.image_id
  instance_type       = var.master_instance_type
  stack_name          = local.master
  cred_id             = local.cred_id
  project_code        = local.project_code
  cost_code           = local.cost_code
  backup_bucket_name  = module.s3backup.backup_bucket_name
  domain_name         = var.domain_name
  instance_profile_name = aws_iam_instance_profile.instance_profile.name
}

module jenkins_slaves {
  source = "./modules/slave"
  aws_region = var.aws_region
  vpc_id = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  private_subnet_cidrs = var.private_subnet_cidrs
  ami_id = data.aws_ami.ubuntu.image_id
  instance_type = var.slave_instance_type
  stack_name = local.slave
  master_url  = module.jenkins_master.master_dns_name
  cred_id    = local.cred_id
  project_code = local.project_code
  cost_code = local.cost_code
  desired_size = var.number_of_slaves
  max_size = var.number_of_slaves
  instance_profile_name = aws_iam_instance_profile.instance_profile.name
}
