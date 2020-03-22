variable "app_name" {
  description = "application base unique name"
}

variable "environment" {
  description = "Name of an environment (e.g. staging, qa, production)"
}

variable "region" {
  description = "AWS region to build this infrastructure"
}

variable "app_image" {
  description = "Docker image of application"
}

variable "app_port" {
  description = "Port exposed by the docker image to redirect traffic to"
}

variable "app_count" {
  description = "Number of docker containers to run"
}

variable "fargate_cpu" {
  description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
}

variable "fargate_memory" {
  description = "Fargate instance memory to provision (in MiB)"
}

variable "scale_min" {
  description = "Minimun nodes to scale down"
}

variable "scale_max" {
  description = "Maximum nodes to scale up"
}

variable "base_domain" {
  description = "base route53-managed top level domain"
}

variable "use_ssl" {
  description = "Use SSL: yes or no"
}

variable "deploy_min_t" {
  description = "Minimum healthy tasks during the deployment"
}

variable "deploy_max_t" {
  description = "Maximum healthy tasks during the deployment"
}

variable "health_check_path" {
  description = "path of healthcheck"
}

variable "vpc_id" {
  description = "vpc id"
}

variable "vpc_cidr" {
  description = "The CIDR block of the vpc"
}

variable "public_subnet" {
  description = "array of public subnets"
  type        = list(string)
}

variable "private_subnet" {
  description = "array of private subnets"
  type        = list(string)
}

variable "db_name" {
  description = "database name"
}

variable "db_username" {
  description = "database username"
}

variable "db_passwd" {
  description = "database password"
}
