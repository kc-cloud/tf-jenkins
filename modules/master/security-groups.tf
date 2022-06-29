resource aws_security_group jenkins_server {
  name        = "${var.stack_name}-sg"
  description = "Seciroty Group for ${var.stack_name}"
  vpc_id      = var.vpc_id

  tags          = {
    "Name"      = var.stack_name
    "project"   = var.project_code
    "cost-code" = var.cost_code
  }
}

# web
resource aws_security_group_rule server_web {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_server.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "jenkins server web"
}

# JNLP for slave agents
resource aws_security_group_rule jnlp {
  type              = "ingress"
  from_port         = 33453
  to_port           = 33453
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_server.id
  cidr_blocks       = var.private_subnet_cidrs
  description       = "jenkins server JNLP Connection"
}

resource aws_security_group_rule server_egress_all {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.jenkins_server.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow all outgoing traffic"
}
