provider "aws" {
  region = var.region
}

provider "cloudflare" {
  version = "~> 2.0"
  api_token = var.cloudflare_api_token
}