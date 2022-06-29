variable aws_region {
  type        = string
  description = "AWS region"
}

variable vpc_id {
  description = "ID of the VPC from which Gateway endpoint is setup"
  type        = string
}

variable tags {
  description = "Tags to be attached to the resources"
  type = map
}

variable namespace {
  type        = string
  description = "Namespace for labels"
}

variable name {
  description = "Name  (e.g. `app`)"
  type        = string
}

variable component_name {
  description = "Name  (e.g. `cluster`)"
  type        = string
}
