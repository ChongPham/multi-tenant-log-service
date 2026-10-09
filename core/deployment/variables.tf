# Values passed by GitHub Actions — do not modify
variable "target_environment" {
  type = string
}

variable "target_stage" {
  type = string
}

# Storage module
variable "config_bucket_name" {
  description = "S3 bucket for OTel collector configs."
  type        = string
}

variable "access_key_secret_name" {
  description = "Secrets Manager secret name for the log collector's Firehose access key."
  type        = string
  default     = "trongpq/access-key"
}

# SOPS-encrypted secret values (core/deployment/secrets/<target_environment>.enc.yaml)
variable "sops_kms_key_admin_arns" {
  description = "IAM principal ARNs (engineers) allowed to encrypt/decrypt with the SOPS KMS key to author secrets locally."
  type        = list(string)
  default     = []
}

variable "ci_role_arn" {
  description = "ARN of the GitHub Actions OIDC role for this environment. Granted decrypt-only access to the SOPS KMS key."
  type        = string
  default     = ""
}

# Cross-account Firehose backup bucket
variable "firehose_backup_bucket_name" {
  description = "Name of the shared S3 bucket for cross-account Firehose failed-delivery backups."
  type        = string
}

variable "firehose_backup_org_id" {
  description = "AWS Organization ID whose member accounts are allowed to read/write their own prefix in the Firehose backup bucket."
  type        = string
  default     = "o-eje0qtdasp"
}

# Observability module
variable "amp_workspace_alias" {
  description = "Alias for the AMP workspace."
  type        = string
}

variable "amg_workspace_name" {
  description = "Name for the AMG workspace."
  type        = string
}

variable "grafana_version" {
  description = "AMG Grafana version."
  type        = string
  default     = "12.4"
}

variable "sso_instance_arn" {
  description = "ARN of the IAM Identity Center instance for AMG auth."
  type        = string
  default     = ""
}
