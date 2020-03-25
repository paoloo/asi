variable "region" {
  description = "AWS region to build this infrastructure"
  default     = "us-east-2"
}

variable "github_token" {
  description = "GitHub OAuth key"
  default     = ""
}

variable "app_name" {
  description = "application base unique name"
  default     = "covidzero"
}

variable "app_port" {
  description = "application port"
  default     = 5000
}

variable "use_ssl" {
  description = "use SSL? yes or no"
  default     = "no"
}

variable "environment" {
  description = "Name of an environment (e.g. staging, qa, production)"
  default     = "staging"
}

variable "repository_owner" {
  description = "Github repository username"
  default     = "paoloo"
}

variable "repository_name" {
  description = "GitHub repository name"
  default     = "st"
}

variable "repository_branch" {
  description = "Github repository branch"
  default     = "master"
}

variable "base_domain" {
  description = "top level domain where application should respond"
  default     = "covidzero.io"
}

variable "vpc_cidr" {
  description = "base CIDR for VPC"
  default     = "10.77.0.0/16"
}

variable "deploy_min_t" {
  description = "Minimum healthy tasks during the deployment"
  default     = 100
}

variable "deploy_max_t" {
  description = "Maximum healthy tasks during the deployment"
  default     = 200
}

variable "scale_min" {
  description = "Minimun nodes to scale down"
  default     = 1
}

variable "scale_max" {
  description = "Maximum nodes to scale up"
  default     = 3
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}

variable "app_count" {
  description = "Number of docker containers to run"
  default     = 1
}

variable "fargate_cpu" {
  description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
  default     = "512"
}

variable "fargate_memory" {
  description = "Fargate instance memory to provision (in MiB)"
  default     = "2048"
}

variable "health_check_path" {
  description = "path for healthcheck"
  default     = "/"
}

variable "db_name" {
  description = "database name"
  default     = "covid"
}

variable "db_username" {
  description = "database username"
  default     = "covid-admin"
}

variable "db_passwd" {
  description = "database password"
  default     = "covid-passwd"
}

variable "cloudflare_api_token" {
  description = "cloudflare api token to be used in integations"
}
