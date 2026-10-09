output "config_bucket_name" {
  description = "S3 bucket holding OTel collector configs."
  value       = module.storage.config_bucket_name
}

output "amp_workspace_arn" {
  description = "ARN of the AMP workspace."
  value       = module.observability.amp_workspace_arn
}

output "amp_workspace_id" {
  description = "ID of the AMP workspace."
  value       = module.observability.amp_workspace_id
}

output "access_key_secret_arn" {
  description = "ARN of the log collector's Firehose access key secret."
  value       = module.storage.access_key_secret_arn
}

output "sops_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt/decrypt SOPS secret files. Needed by engineers to author new/updated secrets locally."
  value       = module.storage.sops_kms_key_arn
}

output "firehose_backup_bucket_name" {
  description = "Name of the shared S3 bucket for cross-account Firehose backup delivery. Give this to onboarded teams."
  value       = module.storage.firehose_backup_bucket_name
}

output "firehose_backup_bucket_arn" {
  description = "ARN of the shared S3 bucket for cross-account Firehose backup delivery."
  value       = module.storage.firehose_backup_bucket_arn
}

output "amp_query_url" {
  description = "AMP query endpoint for Grafana."
  value       = module.observability.amp_query_url
}

output "amg_workspace_endpoint" {
  description = "AMG workspace URL."
  value       = module.observability.amg_workspace_endpoint
}

