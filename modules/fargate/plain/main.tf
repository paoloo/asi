variable "alb_arn" {
}

variable "alb_tg_arn" {
}

variable "base_domain" {
}

resource "aws_alb_listener" "application" {
  load_balancer_arn = var.alb_arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    target_group_arn = var.alb_tg_arn
    type             = "forward"
  }
}

