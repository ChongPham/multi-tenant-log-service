terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4"
    }
  }

  backend "s3" {}
}

provider "aws" {
  default_tags {
    tags = {
      repository  = "trongpq/trongpq"
      environment = var.target_environment
      project     = "trongpq"
      managed_by  = "terraform"
    }
  }
}

