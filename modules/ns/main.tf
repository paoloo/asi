/* ========================================================================= */
/* ================= HOSTNAME ============================================== */
/* ========================================================================= */

/* ============================================= get base domain information */
data "aws_route53_zone" "external" {
  name = var.base_domain
}

/* ================================================= apply the new subdomain */
resource "aws_route53_record" "app-hostname" {
  name    = "${var.app_name}.${var.base_domain}"
  type    = "CNAME"
  ttl     = "300"
  zone_id = data.aws_route53_zone.external.zone_id
  records = [var.alb_url]
}

