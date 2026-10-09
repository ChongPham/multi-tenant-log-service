data "terraform_remote_state" "core" {
  backend = "s3"

  config = {
    bucket = var.core_state_bucket
    key    = var.core_state_key
    region = var.core_state_region
  }
}

locals {
  core = data.terraform_remote_state.core.outputs # Terraform này có thể đọc và sử dụng dữ liệu trạng thái (state file) từ một dự án hoặc môi trường Terraform khác đã được lưu trữ ở remote (ví dụ như trên AWS S3, Terraform Cloud, v.v.).
}

data "aws_region" "current" {}

# --- Shared ECS Cluster ---

resource "aws_ecs_cluster" "collectors" {
  name = var.cluster_name
}

# --- Log Collector ---

module "log_collector" {
  source = "./modules/log-collector"

  cluster_id            = aws_ecs_cluster.collectors.id
  service_name          = var.log_collector_service_name
  vpc_id                = var.vpc_id
  public_subnet_ids     = var.public_subnet_ids
  private_subnet_ids    = var.private_subnet_ids
  access_key_secret_arn = local.core.access_key_secret_arn
  config_bucket_name    = local.core.config_bucket_name
  amp_workspace_arn     = local.core.amp_workspace_arn
  vector_config_files = {
    "base.yaml" = templatefile("../config/log-collector/base.yaml", {
      access_key_secret_id  = local.core.access_key_secret_arn
      aws_region            = data.aws_region.current.region
      amp_remote_write_path = "/workspaces/${local.core.amp_workspace_id}/api/v1/remote_write"
    })
    "tenant-chromeleon.yaml" = file("../config/log-collector/tenant-chromeleon.yaml")
  }
}
