variable "config_bucket_name" {
  description = "Name of the S3 bucket that stores OTel collector configs synced from collectors/ by CI."
  type        = string
}

variable "access_key_secret_name" {
  description = "Name of the Secrets Manager secret holding the log collector's Firehose access key (one key for every onboarded tenant)."
  type        = string
  default     = "trongpq/access-key"
}

variable "sops_kms_key_admin_arns" {
  description = "IAM principal ARNs allowed to encrypt/decrypt with the SOPS KMS key (engineers authoring secrets locally)."
  type        = list(string)
  default     = []
}

variable "ci_role_arn" {
  description = "ARN of the GitHub Actions OIDC role for this environment. Granted decrypt-only access to the SOPS KMS key."
  type        = string
  default     = ""
}

variable "firehose_backup_org_id" {
  description = "AWS Organization ID whose member accounts are allowed to read/write their own prefix in the Firehose backup bucket."
  type        = string
  default     = "o-6i2eqlxlo3"
}

variable "firehose_backup_bucket_name" {
  description = "Name of the shared S3 bucket for cross-account Firehose failed-delivery backups."
  type        = string
}

variable "access_key_value" {
  description = "Decrypted shared collector Firehose access key value (from SOPS), written as the secret's current version."
  type        = string
  sensitive   = true
}