variable "registry_uri" {
  description = "The uri of the ECR repository"
}

variable "environment" {
  description = "Name of an environment (e.g. staging, qa, production)"
  default = "staging"
}

variable "region" {
  description = "The region to use"
}

variable "repository_owner" {
  description = "Github repository username"
}

variable "repository_name" {
  description = "GitHub repository name"
}

variable "repository_branch" {
  description = "Github repository branch"
  default = "master"
}

variable "ecs_cluster_name" {
  description = "The cluster that we will deploy"
}

variable "ecs_service_name" {
  description = "The ECS service that will be deployed"
}

variable "task_subnet_id" {
  type        = "list"
  description = "The subnet id where the ECS task is"
}

variable "task_secgrp_id" {
  type        = "list"
  description = "The security group id list attached to the ECS task"
}

variable "github_token" {
  description = "github oauth key"
}
