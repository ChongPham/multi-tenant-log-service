output "config_bucket_name" {
  description = "Name of the S3 bucket holding OTel collector configs."
  value       = aws_s3_bucket.config.id
}

output "config_bucket_arn" {
  description = "ARN of the S3 bucket holding OTel collector configs."
  value       = aws_s3_bucket.config.arn
}

output "access_key_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the  shared collector's Firehose access key."
  value       = aws_secretsmanager_secret.access_key.arn
}

output "sops_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt/decrypt SOPS secret files."
  value       = aws_kms_key.sops.arn
}

output "firehose_backup_bucket_name" {
  description = "Name of the shared S3 bucket for cross-account Firehose backup delivery."
  value       = aws_s3_bucket.firehose_backup.id
}

output "firehose_backup_bucket_arn" {
  description = "ARN of the shared S3 bucket for cross-account Firehose backup delivery."
  value       = aws_s3_bucket.firehose_backup.arn
}
