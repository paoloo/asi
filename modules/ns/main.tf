/* ========================================================================= */
/* ================= HOSTNAME ============================================== */
/* ========================================================================= */

/* ============================================= get base domain information */
data "cloudflare_zones" "app_hostname" {
  filter {
    name   = var.base_domain
    status = "active"
    paused = false
  }
}

/* ================================================= apply the new subdomain */
resource "cloudflare_record" "app_hostname" {
  proxied = var.is_proxied
  zone_id = data.cloudflare_zones.app_hostname.zones[0].id
  name    = "${var.app_name}.${var.base_domain}"
  value   = var.alb_url
  type    = "CNAME"
  ttl     = "1"
}
