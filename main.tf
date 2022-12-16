terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
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

resource "aws_ecr_repository" "bingoapp" {
  name = "bingoapp"
}

resource "aws_ecs_cluster" "env_bingoapp_prod" {
  name = "env-bingoapp-prod"
}


resource "aws_ecs_task_definition" "bingoapp_task" {
  family                   = "bingoapp-task"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "bingoapp-task",
      "image": "${var.image_bingoapp}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

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

resource "aws_ecs_service" "bingoapp_service" {
  name            = "bingoapp-service"                        # Naming our first service
  cluster         = aws_ecs_cluster.env_bingoapp_prod.id      # Referencing our created Cluster
  task_definition = aws_ecs_task_definition.bingoapp_task.arn # Referencing the task our service will spin up
  launch_type     = "FARGATE"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn # Referencing our target group
    container_name   = aws_ecs_task_definition.bingoapp_task.family
    container_port   = 8080 # Specifying the container port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}"]
    assign_public_ip = true                                                # Providing our containers with public IPs
    security_groups  = ["${aws_security_group.service_security_group.id}"] # Setting the security group
  }
}


resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



# imported already with terraform import aws_route53_zone.bingoapp_zone <HOSTED_ZONE_ID>
resource "aws_route53_zone" "bingoapp_zone" {
  name = "simonsbingo.com"
}

resource "aws_acm_certificate" "simonsbingo_com" {
  domain_name = "simonsbingo.com"
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
  name    = "simonsbingo.com"
  type    = "A"

  alias {
    name                   = aws_alb.bingoapp_load_balancer.dns_name
    zone_id                = aws_alb.bingoapp_load_balancer.zone_id
    evaluate_target_health = true
  }
}