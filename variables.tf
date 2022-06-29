variable aws_region {
    description = "Region to deploy the stack"
}

variable project_name       {
    description = "Name of the stack"
    default = "kc"
}

variable name       {
    description = "Name of the stack"
    default = "jenkins"
}

variable environment  {
    description = "Name of the stack"
}

variable vpc_id {
    description = "VPC to deploy the stack"
}

variable public_subnet_ids {
    description = "Public subnets to provision Load Balancer"
    type = list(string)
}

variable private_subnet_cidrs {
    description = "Public subnet CIDR blocks to provision Load Balancer"
    type = list(string)
}

variable private_subnet_ids {
    description = "Private subnets to provision EC2 instances"
    type = list(string)
}

variable private_subnet_cidrs {
    description = "Private subnet CIDR blocks to provision EC2 instances"
    type = list(string)
}

variable master_instance_type {
    default = "m5.large"
}

variable slave_instance_type {
    default = "m5.large"
}

variable domain_name {
    type = string
}