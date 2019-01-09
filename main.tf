provider "aws" {
  shared_credentials_file = "$HOME/.aws/credentials"
  profile                 = "default"
  region                  = "${var.region}"
}

module "registry" {
  source                  = "./modules/registry"
  app_name                = "${var.app_name}"
  environment             = "${var.environment}"
}

module "fargate" {
  source                  = "./modules/fargate"
  app_name                = "${var.app_name}"
  app_port                = "${var.app_port}"
  vpc_cidr                = "${var.vpc_cidr}"
  app_image               = "${module.registry.repository_uri}:latest"
  scale_min               = "${var.scale_min}"
  scale_max               = "${var.scale_max}"
}

module "buildndeploy" {
  source                  = "./modules/buildndeploy"
  environment             = "${var.environment}"
  region                  = "${var.region}"
  registry_uri            = "${module.registry.repository_uri}"
  repository_owner        = "${var.repository_owner}"
  repository_name         = "${var.repository_name}"
  repository_branch       = "${var.repository_branch}"
  ecs_cluster_name        = "${module.fargate.cluster_name}"
  ecs_service_name        = "${module.fargate.service_name}"
  task_subnet_id          = "${module.fargate.task_subnet_id}"
  task_secgrp_id          = "${module.fargate.task_secgrp_id}"
  github_token            = "${var.github_token}"
}

module "hostname" {
  source                  = "./modules/ns"
  app_name                = "${var.app_name}"
  alb_url                 = "${module.fargate.alb_hostname}"
  base_domain             = "${var.base_domain}"
}

output "app_hn" {
  value = "${module.hostname.name}"
}
