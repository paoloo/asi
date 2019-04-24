
variable "base_domain" {}
variable "alb_arn" {}
variable "alb_tg_arn" {}

data "aws_acm_certificate" "app-ssl" {
  domain   = "*.${var.base-domain}"
  statuses = ["ISSUED"]
}

resource "aws_alb_listener" "application" {
  load_balancer_arn = "${var.alb_arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${data.aws_acm_certificate.app-ssl.arn}"
  default_action {
    target_group_arn = "${var.alb_tg_arn}"
    type             = "forward"
  }
}

