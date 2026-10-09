# Deployment prerequisite: verify the IAM role ARNs below against existing AWS roles.
# Renaming an SSO permission set can change the generated role suffix; do not infer its ARN.
config_bucket_name          = "TODO"
firehose_backup_bucket_name = "TODO"

amp_workspace_alias = "trongpq-prod"
amg_workspace_name  = "trongpq-prod"

# TODO: fill in before first apply — ARN of the GitHub Actions OIDC role for trongpq-prod
ci_role_arn = "arn:aws:iam::174772361218:role/TrongpqTerraformProd"

# TODO: fill in before first apply — IAM ARNs of engineers allowed to author SOPS secrets locally
sops_kms_key_admin_arns = ["arn:aws:iam::174772361218:role/aws-reserved/sso.amazonaws.com/eu-central-1/AWSReservedSSO_TrongpqAdmin_fc244a90f0662565"]
