
resource aws_security_group jenkins_slave {
  name        = "${var.stack_name}-sg"
  description = "Seciroty Group for ${var.stack_name}"
  vpc_id      = var.vpc_id
  tags          = {
    "Name"      = var.stack_name
    "project"   = var.project_code
    "cost-code" = var.cost_code
  }
}

# ssh
resource aws_security_group_rule slave_ssh {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_slave.id
  cidr_blocks       = toset(var.private_subnet_cidrs)
  description       = "jenkins server ssh"
}

# web
resource aws_security_group_rule slave_web {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_slave.id
  cidr_blocks       = [ "0.0.0.0/0" ]
  description       = "jenkins server web"
}

resource aws_security_group_rule slave_egress_all {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.jenkins_slave.id
  cidr_blocks       = [ "0.0.0.0/0" ]
  description       = "allow all outgoing traffic"
}