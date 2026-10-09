data "sops_file" "secrets" {
  source_file = "${path.module}/secrets/${var.target_environment}.enc.yaml"
}

# Kết nối Grafana với AMP bằng outputs của observability
module "observability" {
  source              = "./modules/observability"
  amp_workspace_alias = var.amp_workspace_alias
  amg_workspace_name  = var.amg_workspace_name
  grafana_version     = var.grafana_version
  sso_instance_arn    = var.sso_instance_arn
}

module "storage" {
  source = "./modules/storage"

  config_bucket_name          = var.config_bucket_name
  access_key_secret_name      = var.access_key_secret_name
  access_key_value            = data.sops_file.secrets.data["access_key"]
  sops_kms_key_admin_arns     = var.sops_kms_key_admin_arns
  ci_role_arn                 = var.ci_role_arn
  firehose_backup_bucket_name = var.firehose_backup_bucket_name
  firehose_backup_org_id      = var.firehose_backup_org_id
}

#  Grafana xử lý việc ký request trong data source, nên không cần chạy container SigV4 proxy riêng như nhánh Vector
resource "grafana_data_source" "amp" {
  name = "Amazon Managed Prometheus"
  type = "grafana-amazonprometheus-datasource"
  url  = module.observability.amp_endpoint

  json_data_encoded = jsonencode({
    httpMethod    = "POST"
    sigV4Auth     = true
    sigV4AuthType = "default"
    sigV4Region   = "eu-central-1"
    sigv4Service  = "aps"
  })
}