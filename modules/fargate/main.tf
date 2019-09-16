/* ========================================================================= */
/* ================= LOGS ================================================== */
/* ========================================================================= */

resource "aws_cloudwatch_log_group" "main" {
  name = "${var.app_name}-${var.environment}-log-grp-app"
  tags = {
    Environment = var.environment
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
  subnets         = var.public_subnet
  security_groups = [aws_security_group.lb.id]
  tags = {
    Name        = "${var.app_name}-${var.environment}-alb"
    Environment = var.environment
  }
}

resource "aws_alb_target_group" "app" {
  name        = "${var.app_name}-${var.environment}-alb-${random_id.tgs.hex}"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  lifecycle {
    create_before_destroy = true
  }
  health_check {
    healthy_threshold   = 5
    unhealthy_threshold = 5
    timeout             = 10
    interval            = 30
    path                = var.health_check_path
  }
}

module "alb_listener" {
  /* === source      = "${var.use_ssl == "yes" ? ./ssl : ./plain}" === terraform v0.12.? */
  source      = "./plain"
  alb_arn     = aws_alb.main.arn
  alb_tg_arn  = aws_alb_target_group.app.arn
  base_domain = var.base_domain
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
  execution_role_arn       = aws_iam_role.ecs-role.arn
  task_role_arn            = aws_iam_role.ecs-role.arn
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  container_definitions    = <<DEFINITION
[
  {
    "cpu": ${var.fargate_cpu},
    "image": "${var.app_image}",
    "memory": ${var.fargate_memory},
    "name": "app",
    "networkMode": "awsvpc",
    "ulimits": [
      {
        "name": "nofile",
        "softLimit": 1000000,
        "hardLimit": 1000000
      }
    ],
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
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.app.arn
  desired_count                      = var.app_count
  deployment_minimum_healthy_percent = var.deploy_min_t
  deployment_maximum_percent         = var.deploy_max_t
  launch_type                        = "FARGATE"
  network_configuration {
    security_groups = [aws_security_group.ecs_tasks.id]
    subnets         = var.private_subnet
  }
  load_balancer {
    target_group_arn = aws_alb_target_group.app.id
    container_name   = "app"
    container_port   = var.app_port
  }
  depends_on = [module.alb_listener]
}

/* ========================================================================= */
/* ================= AUTO SCALING ========================================== */
/* ========================================================================= */
resource "aws_appautoscaling_target" "target" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  role_arn           = aws_iam_role.ecs-role.arn
  min_capacity       = var.scale_min
  max_capacity       = var.scale_max
}

/* ======================================= auto scaling metric to scaling up */
resource "aws_appautoscaling_policy" "scale_up" {
  name               = "${var.environment}-scale-up"
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"
    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
  depends_on = [aws_appautoscaling_target.target]
}

/* ===================================== auto scaling metric to scaling down */
resource "aws_appautoscaling_policy" "scale_down" {
  name               = "${var.environment}-scale-down"
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"
    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = -1
    }
  }
  depends_on = [aws_appautoscaling_target.target]
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
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.main.name
  }
  alarm_actions = [aws_appautoscaling_policy.scale_up.arn]
  ok_actions    = [aws_appautoscaling_policy.scale_down.arn]
}

/* ========================================================================= */
/* ================= SECURITY ============================================== */
/* ========================================================================= */

/* ====================================================== ALB Security group */
resource "aws_security_group" "lb" {
  name        = "${var.app_name}-${var.environment}-ecs-alb"
  description = "controls access to the ALB"
  vpc_id      = var.vpc_id
  ingress {
    protocol    = "tcp"
    from_port   = "${var.use_ssl == "yes" ? 443 : 80}"
    to_port     = "${var.use_ssl == "yes" ? 443 : 80}"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Environment = var.environment
  }
}

/* ============================================ ALB->ECS Cluster-only access */
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.app_name}-${var.environment}-ecs-tasks"
  description = "allow inbound access from the ALB only"
  vpc_id      = var.vpc_id
  ingress {
    protocol        = "tcp"
    from_port       = var.app_port
    to_port         = var.app_port
    security_groups = [aws_security_group.lb.id]
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
  name               = "${var.app_name}-${var.environment}-ecs-role"
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
  name   = "${var.app_name}-${var.environment}-ecs-policy"
  role   = aws_iam_role.ecs-role.id
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

