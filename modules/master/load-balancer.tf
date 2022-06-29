resource aws_security_group alb_sg {
  name   = "${var.stack_name}-alb-sg"
  vpc_id = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource aws_security_group_rule alb_sg_egress {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

resource aws_security_group_rule alb_sg_443 {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

## ELB
resource aws_lb alb {
  name                              = "${var.stack_name}-alb"
  internal                          = false
  load_balancer_type                = "application"
  subnets                           = var.public_subnet_ids
  security_groups                   = [aws_security_group.alb_sg.id]
  enable_deletion_protection        = false
  enable_cross_zone_load_balancing  = true
  idle_timeout                      = 600

  tags = {
    "Name"      = var.stack_name
    "project"   = var.project_code
    "cost-code" = var.cost_code
  }
}

resource aws_lb_target_group alb_tg {
  name_prefix   = "jenkin"
  port          = 8080
  protocol      = "HTTP"
  vpc_id        = var.vpc_id
  deregistration_delay = 20

  stickiness {
    type = "lb_cookie"
    cookie_duration = 86400  # 1 day in secs
    enabled = true
  }

  health_check {
    protocol = "HTTP"
    interval = 10
    path = "/"
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
    matcher = "200"
  }
}

resource aws_lb_listener alb_listener {
  depends_on = [aws_lb.alb, aws_lb_target_group.alb_tg, aws_iam_server_certificate.alb_cert]
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_iam_server_certificate.alb_cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}

data aws_route53_zone domain {
  name     = domain_name
}

resource aws_route53_record jenkins {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}
