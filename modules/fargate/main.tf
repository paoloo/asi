/* ========================================================================= */
/* ================= NETWORKING ============================================ */
/* ========================================================================= */

/* ========================================= Fetch AZs in the current region */
data "aws_availability_zones" "available" {}

/* ===================================================================== VPC */
resource "aws_vpc" "main" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags {
    Name        = "${var.environment}-vpc"
    Environment = "${var.environment}"
  }
}

/* ========================================================== Private subnet */
resource "aws_subnet" "private" {
  count                   = "${var.az_count}"
  cidr_block              = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id                  = "${aws_vpc.main.id}"
  map_public_ip_on_launch = false
  tags {
    Environment = "${var.environment}"
  }
}

/* =========================================================== Public subnet */
resource "aws_subnet" "public" {
  count                   = "${var.az_count}"
  cidr_block              = "${cidrsubnet(aws_vpc.main.cidr_block, 8, var.az_count + count.index)}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id                  = "${aws_vpc.main.id}"
  map_public_ip_on_launch = true
  tags {
    Environment = "${var.environment}"
  }
}

/* ======================================================== Internet gateway */
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
  tags {
    Name        = "${var.environment}-igw"
    Environment = "${var.environment}"
  }
}

/* ====================================================== Elastic IP for NAT */
resource "aws_eip" "gw" {
  count      = "${var.az_count}"
  vpc        = true
  depends_on = ["aws_internet_gateway.gw"]
}

/* ===================================================================== NAT */
resource "aws_nat_gateway" "gw" {
  count         = "${var.az_count}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
  allocation_id = "${element(aws_eip.gw.*.id, count.index)}"
  tags {
    Environment = "${var.environment}"
  }
}

/* ========================================= Routing table for public subnet */
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"
}

/* ======================================== Routing table for private subnet */
resource "aws_route_table" "private" {
  count  = "${var.az_count}"
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.gw.*.id, count.index)}"
  }
}
/* ================================================ Route table association */
resource "aws_route_table_association" "private" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

/* ========================================================================= */
/* ================= LOGS ================================================== */
/* ========================================================================= */

resource "aws_cloudwatch_log_group" "main" {
  name = "${var.app_name}-${var.environment}-log-grp-app"
  tags {
    Environment = "${var.environment}"
  }
}

/* ========================================================================= */
/* ================= ALB =================================================== */
/* ========================================================================= */
resource "random_id" "tgs" {
  byte_length = 4
}

resource "aws_alb" "main" {
  name            = "${var.app_name}-${var.environment}-alb"
  subnets         = ["${aws_subnet.public.*.id}"]
  security_groups = ["${aws_security_group.lb.id}"]
  tags {
    Name        = "${var.app_name}-${var.environment}-alb"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_target_group" "app" {
  name        = "${var.app_name}-${var.environment}-alb-${random_id.tgs.hex}"
  port        = "${var.app_port}"
  protocol    = "HTTP"
  vpc_id      = "${aws_vpc.main.id}"
  target_type = "ip"
  lifecycle {
    create_before_destroy = true
  }
}

module "alb_listener" {
  /* === source      = "${var.environment_name == true ? ./ssl : ./plain}" === terraform v0.12.? */
  source      = "./plain"
  alb_arn     = "${aws_alb.main.arn}"
  alb_tg_arn  = "${aws_alb_target_group.app.arn}"
  base_domain = "${var.base_domain}"
}

/* ========================================================================= */
/* ================= ECS =================================================== */
/* ========================================================================= */
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-${var.environment}-ecs-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = "${aws_iam_role.ecs-role.arn}"
  task_role_arn            = "${aws_iam_role.ecs-role.arn}"
  cpu                      = "${var.fargate_cpu}"
  memory                   = "${var.fargate_memory}"
  container_definitions = <<DEFINITION
[
  {
    "cpu": ${var.fargate_cpu},
    "image": "${var.app_image}",
    "memory": ${var.fargate_memory},
    "name": "app",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": ${var.app_port},
        "hostPort": ${var.app_port}
      }
    ],
    "logConfiguration": {
	    "logDriver": "awslogs",
	    "options": {
	        "awslogs-group": "${aws_cloudwatch_log_group.main.name}",
	        "awslogs-region": "${var.region}",
	        "awslogs-stream-prefix": "${var.app_name}-${var.environment}"
	    }
	}

  }
]
DEFINITION
}

resource "aws_ecs_service" "main" {
  name                               = "${var.app_name}-${var.environment}-ecs-service"
  cluster                            = "${aws_ecs_cluster.main.id}"
  task_definition                    = "${aws_ecs_task_definition.app.arn}"
  desired_count                      = "${var.app_count}"
  deployment_minimum_healthy_percent = "${var.deploy_min_t}"
  deployment_maximum_percent         = "${var.deploy_max_t}"
  launch_type                        = "FARGATE"
  network_configuration {
    security_groups = ["${aws_security_group.ecs_tasks.id}"]
    subnets         = ["${aws_subnet.private.*.id}"]
  }
  load_balancer {
    target_group_arn = "${aws_alb_target_group.app.id}"
    container_name   = "app"
    container_port   = "${var.app_port}"
  }
  depends_on = [
    "module.alb_listener",
  ]
}


/* ========================================================================= */
/* ================= AUTO SCALING ========================================== */
/* ========================================================================= */
resource "aws_appautoscaling_target" "target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  role_arn           = "${aws_iam_role.ecs-role.arn}"
  min_capacity       = "${var.scale_min}"
  max_capacity       = "${var.scale_max}"
}

/* ======================================= auto scaling metric to scaling up */
resource "aws_appautoscaling_policy" "scale_up" {
  name                    = "${var.environment}-scale-up"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension      = "ecs:service:DesiredCount"
  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"
    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = 1
    }
  }
  depends_on = ["aws_appautoscaling_target.target"]
}

/* ===================================== auto scaling metric to scaling down */
resource "aws_appautoscaling_policy" "scale_down" {
  name                    = "${var.environment}-scale-down"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension      = "ecs:service:DesiredCount"
  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"
    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = -1
    }
  }
  depends_on = ["aws_appautoscaling_target.target"]
}

/* ========================================== Auto Scaling metric definition */
resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  alarm_name          = "${var.app_name}-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "70"
  dimensions {
    ClusterName = "${aws_ecs_cluster.main.name}"
    ServiceName = "${aws_ecs_service.main.name}"
  }
  alarm_actions = ["${aws_appautoscaling_policy.scale_up.arn}"]
  ok_actions    = ["${aws_appautoscaling_policy.scale_down.arn}"]
}


/* ========================================================================= */
/* ================= SECURITY ============================================== */
/* ========================================================================= */

/* ====================================================== ALB Security group */
resource "aws_security_group" "lb" {
  name        = "${var.app_name}-${var.environment}-ecs-alb"
  description = "controls access to the ALB"
  vpc_id      = "${aws_vpc.main.id}"
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Environment = "${var.environment}"
  }
}

/* ============================================ ALB->ECS Cluster-only access */
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.app_name}-${var.environment}-ecs-tasks"
  description = "allow inbound access from the ALB only"
  vpc_id      = "${aws_vpc.main.id}"
  ingress {
    protocol        = "tcp"
    from_port       = "${var.app_port}"
    to_port         = "${var.app_port}"
    security_groups = ["${aws_security_group.lb.id}"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/* ================================================== ECS policies and roles */

resource "aws_iam_role" "ecs-role" {
  name = "${var.app_name}-${var.environment}-ecs-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "ecs.amazonaws.com",
          "ec2.amazonaws.com",
          "ecs-tasks.amazonaws.com",
          "application-autoscaling.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecs-policy" {
  name = "${var.app_name}-${var.environment}-ecs-policy"
  role = "${aws_iam_role.ecs-role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "ecs:DescribeServices",
        "ecs:UpdateService",
        "cloudwatch:DescribeAlarms",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "ec2:Describe*",
        "ec2:AuthorizeSecurityGroupIngress"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

