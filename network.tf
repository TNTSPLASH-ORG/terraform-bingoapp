resource "aws_alb" "bingoapp_load_balancer" {
  name               = "bingoapp-lb-tf"
  load_balancer_type = "application"
  subnets = [ # Referencing the default subnets
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}"
  ]
  # Referencing the security group
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

# Providing a reference to our default VPC
resource "aws_default_vpc" "default_vpc" {
}

# Providing a reference to our default subnets
resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "us-west-1a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "us-west-1b"
}

# Creating a security group for the load balancer:
resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id # Referencing the default VPC
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_alb.bingoapp_load_balancer.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.simonsbingo_com.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_route53_zone" "bingoapp_zone" {
  name = var.site_name
}

resource "aws_acm_certificate" "simonsbingo_com" {
  domain_name = var.site_name
  subject_alternative_names = [
    "*.simonsbingo.com"
  ]
  validation_method = "DNS"
}

resource "aws_route53_record" "simonsbingo_validation" {
  for_each = {
    for dvo in aws_acm_certificate.simonsbingo_com.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.bingoapp_zone.zone_id # aws_route53_zone.simonsbingo_com.zone_id
}

resource "aws_acm_certificate_validation" "simonsbingo_com" {
  certificate_arn         = aws_acm_certificate.simonsbingo_com.arn
  validation_record_fqdns = [for record in aws_route53_record.simonsbingo_validation : record.fqdn]
}

resource "aws_route53_record" "alias_route53_record" {
  zone_id = aws_route53_zone.bingoapp_zone.zone_id
  name    = var.site_name
  type    = "A"

  alias {
    name                   = aws_alb.bingoapp_load_balancer.dns_name
    zone_id                = aws_alb.bingoapp_load_balancer.zone_id
    evaluate_target_health = true
  }
}