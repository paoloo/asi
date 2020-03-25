variable "app_name" {
  description = "application base unique name"
}

variable "base_domain" {
  description = "top level domain where application should respond"
}

variable "alb_url" {
  description = "URL to register the ALB"
}

variable "is_proxied" {
  description = "Whether the record gets Cloudflare's origin protection; defaults to `false`."
  default = false
}
