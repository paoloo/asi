variable "region" {
  description = "AWS region to build this infrastructure"
  default = "us-east-1"
}

variable "github_token" {
  description = "GitHub OAuth key"
  default = "add your token here"
}

variable "app_name" {
  description = "application base unique name"
  default = "testium"
}

variable "app_port" {
  description = "application port"
  default = 5000
}

variable "environment" {
  description = "Name of an environment (e.g. staging, qa, production)"
  default = "staging"
}

variable "repository_owner" {
  description = "Github repository username"
  default = "paoloo"
}

variable "repository_name" {
  description = "GitHub repository name"
  default = "st"
}

variable "repository_branch" {
  description = "Github repository branch"
  default = "master"
}

variable "base_domain" {
  description = "top level domain where application should respond"
  default ="the-real-domain-dev.io"
}

variable "vpc_cidr" {
  description = "base CIDR for VPC"
  default = "10.77.0.0/16"
}

variable "scale_min" {
  description = "Minimun nodes to scale down"
  default = 1
}

variable "scale_max" {
  description = "Maximum nodes to scale up"
  default = 3
}
