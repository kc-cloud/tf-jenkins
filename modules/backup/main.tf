
terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

locals {
  RESOURCE_NAME_PREFIX = "${var.namespace}-${var.name}-${var.component_name}"
}

resource aws_s3_bucket backup_bucket {
  bucket        = local.RESOURCE_NAME_PREFIX
  tags          = var.tags
  force_destroy = true
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
      }
    }
  }
  versioning {
    enabled     = true
    mfa_delete  = false
  }
}

resource aws_s3_bucket_public_access_block hix-s3-bucket-public-access-block {
  bucket = aws_s3_bucket.backup_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource aws_vpc_endpoint backup_bucket_endpoint {
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_id            = var.vpc_id
}