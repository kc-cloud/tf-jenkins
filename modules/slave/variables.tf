variable aws_region {
    description = "Region to deploy the stack"
}
variable vpc_id {
    description = "VPC to deploy the stack"
}
variable stack_name {
    description = "Name of the stack"
}

variable private_subnet_ids {
    description = "Private subnets to provision EC2 instances"
}

variable private_subnet_cidrs {
    description = "Private subnet CIDR blocks to provision EC2 instances"
}

variable ami_id {
    description = "Ubuntu AMI from AWS"
}

variable instance_type {
    description = "Type of instance"
}

variable desired_size {
    description = "Desired count of instances required"
    default = 2
}

variable max_size {
    description = "Maximum number of instances allowed"
    default = 3
}

variable master_url {
    description = "URL where master is accessible"
}

variable cred_id {
    description = "Credential ID that Master uses to add and connect slaves"
}

variable project_code {
    description = "Project Code to tag the resources with"
}

variable cost_code {
    description = "Cost Code to tag the resources with"    
}

variable instance_profile_name {
    description = "Instance profile to attach to slaves"
}