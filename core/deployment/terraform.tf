terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
  # empty backend initialization
  # configuration provided by CI
  backend "s3" {}
}

# Role is assumed via GitHub actions and STS credentials are already exported
# https://github.com/aws-actions/configure-aws-credentials

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

provider "grafana" {
  url  = "https://${module.observability.amg_workspace_endpoint}"
  auth = module.observability.grafana_service_account_token
}
