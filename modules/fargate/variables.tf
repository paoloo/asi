variable "app_name" {
  description = "application base unique name"
}

variable "environment" {
  description = "Name of an environment (e.g. staging, qa, production)"
  default = "staging"
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default = "2"
}

variable "vpc_cidr" {
  description = "The CIDR block of the vpc"
  default = "10.66.0.0/16"
}

variable "app_image" {
  description = "Docker image of application"
}

variable "app_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  default = 5000
}

variable "app_count" {
  description = "Number of docker containers to run"
  default = 1
}

variable "fargate_cpu" {
  description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
  default = "512"
}

variable "fargate_memory" {
  description = "Fargate instance memory to provision (in MiB)"
  default = "2048"
}

variable "scale_min" {
  description = "Minimun nodes to scale down"
  default = 1
}

variable "scale_max" {
  description = "Maximum nodes to scale up"
  default = 3
}
