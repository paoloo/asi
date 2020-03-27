resource "aws_db_subnet_group" "main" {
  name = "${var.app_name}-${var.environment}-db-sngrp"
  description = "DB subnet group for  ${var.environment} env"
  subnet_ids = var.private_subnet
}

resource "aws_rds_cluster" "default" {
  cluster_identifier = "db-${var.app_name}-${var.environment}"
  database_name = var.db_name
  master_username = var.db_username
  master_password = var.db_passwd
  skip_final_snapshot = false
  enable_http_endpoint = true
  storage_encrypted = true
  backup_retention_period = "1"
  db_subnet_group_name = aws_db_subnet_group.main.name
  engine = "aurora-postgresql"
  engine_mode = "serverless"
  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]
  scaling_configuration {
    auto_pause = true
    max_capacity = 4
    min_capacity = 2
    seconds_until_auto_pause = 30000
  }

  tags = {
    Terraform = true 
  }
}

resource "aws_security_group" "rds" {
  name = "${var.app_name}-${var.environment}-secgrp-rds"
  description = "controls access to the database"
  vpc_id = var.vpc_id
  ingress {
    protocol = "tcp"
    from_port = 5432
    to_port = 5432
    cidr_blocks = [
      var.vpc_cidr]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}
