variable "environment"       { description = "Name of an environment (e.g. staging, qa, production)"             }
variable "region"            { description = "AWS region to build this infrastructure"                           }
variable "az_count"          { description = "Number of AZs to cover in a given AWS region"                      }
variable "vpc_cidr"          { description = "The CIDR block of the vpc"                                         }

