provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket = "covidzero-tfstate"
    key    = "staging/covidzero.tfstate"
    region = "us-east-2"
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "covidzero-tfstate"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "app-state"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

