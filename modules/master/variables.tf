variable aws_region {
    description = "Region to deploy the stack"
}
variable vpc_id {
    description = "VPC to deploy the stack"
}
variable stack_name {
    description = "Name of the stack"
}

variable public_subnet_ids {
    description = "Public subnets to provision load balancer"
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
    default     = "m5.large"   
}

variable cred_id {
    description = "Credential ID that Master uses to add and connect slaves"
}

variable backup_bucket_name {
    description = "S3 bucket to take the backup of the Jenkins configurations"
}

variable project_code {
    description = "Project Code to tag the resources with"
}

variable cost_code {
    description = "Cost Code to tag the resources with"    
}

variable domain_name {
    description = "Domain name for the Jenkins URL."
}

variable instance_profile_name {
    description = "Instance profile to attach to slaves"
}