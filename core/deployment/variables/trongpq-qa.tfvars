# Deployment prerequisite: verify the IAM role ARNs below against existing AWS roles.
# Renaming an SSO permission set can change the generated role suffix; do not infer its ARN.
config_bucket_name          = "trongpq-collector-config-qa-trong"
firehose_backup_bucket_name = "trongpq-firehose-backup-qa-trong"

amp_workspace_alias = "trongpq-qa"
amg_workspace_name  = "trongpq-qa"

ci_role_arn = "arn:aws:iam::174772361218:role/CI-role"

sops_kms_key_admin_arns = [
  "arn:aws:iam::174772361218:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_TrongpqAdmin_f05f1a4ac2c436b2",
]
