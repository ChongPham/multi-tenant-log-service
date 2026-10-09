# Lưu file cấu hình của Collector, Khi CI đồng bộ/cập nhật cấu hình, Các file cấu hình như YAML
#   1. Bạn sửa collectors/collector.yaml trong Git
#  2. CI upload file đó lên s3://ten-bucket/collector.yaml
#  3. Máy/container chạy collector tải file từ S3
#  4. Collector đọc file và chạy theo cấu hình đó
resource "aws_s3_bucket" "config" {
  bucket = var.config_bucket_name
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Đoạn code Terraform này dùng để bật toàn bộ các lớp khiên chặn truy cập công khai (Public Access Block) cho một S3 Bucket cụ thể trong hệ thống.
resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# tạo một “chỗ chứa secret” trên AWS Secrets Manager, dành để lưu access key xác thực giữa Firehose và Vector.
resource "aws_secretsmanager_secret" "access_key" {
  name                    = var.access_key_secret_name
  description             = "Firehose access key shared by every tenant on the log collector fleet. Value managed via SOPS (core/deployment/secrets/*.enc.yaml)."
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "access_key" {
  secret_id = aws_secretsmanager_secret.access_key.id
  # JSON-wrapped, not a bare string: Vector's aws_secrets_manager secrets
  # backend (used by the shared collector to read this at its own startup,
  # not via ECS env-var injection) requires the SecretString to be a JSON
  # object.
  secret_string = jsonencode({ access_key = var.access_key_value })
}

data "aws_caller_identity" "current" {}

#  - aws_iam_policy_document.sops_key: quy định ai được dùng khóa — kỹ sư được mã hóa/giải mã, CI được giải mã.
#  - aws_kms_key.sops: tạo khóa KMS và gắn các quyền trên vào khóa.
#  - aws_kms_alias.sops: đặt tên dễ nhớ cho khóa là alias/trongpq-sops.
data "aws_iam_policy_document" "sops_key" {
  statement {
    sid       = "EnableRootAccountPermissions"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  dynamic "statement" {
    for_each = length(var.sops_kms_key_admin_arns) > 0 ? [1] : []
    content {
      sid       = "AllowEngineersEncryptDecrypt"
      actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = var.sops_kms_key_admin_arns
      }
    }
  }

  dynamic "statement" {
    for_each = var.ci_role_arn != "" ? [1] : []
    content {
      sid       = "AllowCIDecryptOnly"
      actions   = ["kms:Decrypt", "kms:DescribeKey"]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = [var.ci_role_arn]
      }
    }
  }
}

resource "aws_kms_key" "sops" {
  description             = "SOPS encryption key for secret values committed to git (core/deployment/secrets/*.enc.yaml)."
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.sops_key.json
}

resource "aws_kms_alias" "sops" {
  name          = "alias/trongpq-sops"
  target_key_id = aws_kms_key.sops.key_id
}

# --- Shared S3 bucket for cross-account Firehose backup delivery ---
#
# Onboarded systems' Firehose delivery streams write failed-delivery backups
# here instead of provisioning their own bucket. Each account can only
# read/write under its own account-ID prefix (enforced by the bucket policy
# below). Firehose's cross-account S3 delivery uses ACLs (it always sends
# x-amz-acl: bucket-owner-full-control), so this bucket must keep ACLs
# enabled via "BucketOwnerPreferred" -- the account/bucket default since
# 2023 is "BucketOwnerEnforced" (ACLs disabled), which would silently break
# delivery if left as-is.

#Lưu dữ liệu backup của Firehose, Dữ liệu Firehose nhận được, chẳng hạn logs, Tùy cấu hình Firehose: backup toàn bộ hoặc chỉ dữ liệu gửi thất bại 
resource "aws_s3_bucket" "firehose_backup" {
  bucket = var.firehose_backup_bucket_name
}

resource "aws_s3_bucket_versioning" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Toàn bộ quyền hạn trong policy này chỉ có tác dụng với các thực thể (IAM Role/User) 
# nằm bên trong cùng một AWS Organization (được chỉ định qua biến var.firehose_backup_org_id).
data "aws_iam_policy_document" "firehose_backup" {
  statement {
    sid       = "AllowMemberAccountsConsoleAccess"
    actions   = ["s3:GetBucketLocation"]
    resources = [aws_s3_bucket.firehose_backup.arn]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [var.firehose_backup_org_id]
    }
  }

  # Account nào thì chỉ được phép list thư mục có tên trùng với số ID của chính account đó (ví dụ: 123456789012/*).
  statement {
    sid       = "AllowMemberAccountsPrefixLevel"
    actions   = ["s3:ListBucketVersions", "s3:ListBucket"]
    resources = [aws_s3_bucket.firehose_backup.arn]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [var.firehose_backup_org_id]
    }
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["", "$${aws:PrincipalAccount}/*"]
    }
  }

  # Giới hạn chặt chẽ bên trong đường dẫn riêng của từng tài khoản:
  statement {
    sid       = "AllowMemberAccountsObjectRead"
    actions   = ["s3:GetObjectVersion", "s3:GetObject"]
    resources = ["${aws_s3_bucket.firehose_backup.arn}/$${aws:PrincipalAccount}/*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [var.firehose_backup_org_id]
    }
  }

  # Firehose assumes an IAM role created in the member account (not a bare
  # service principal) to write here -- see S3Configuration.RoleARN in the
  # onboarding doc. That role's own identity policy also needs PutObject +
  # PutObjectAcl on this bucket; this statement alone is not sufficient.
  #
  # PutObject/PutObjectAcl carry the s3:x-amz-acl condition because Firehose
  # sets that header on every write. AbortMultipartUpload doesn't send that
  # header at all, so it can't share a statement with a condition on it --
  # AWS rejects the whole statement with "Conditions do not apply to
  # combination of actions and resources" if you try.
  statement {
    sid       = "AllowMemberAccountsFirehoseWrite"
    actions   = ["s3:PutObject", "s3:PutObjectAcl"]
    resources = ["${aws_s3_bucket.firehose_backup.arn}/$${aws:PrincipalAccount}/*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [var.firehose_backup_org_id]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid       = "AllowMemberAccountsAbortMultipartUpload"
    actions   = ["s3:AbortMultipartUpload"]
    resources = ["${aws_s3_bucket.firehose_backup.arn}/$${aws:PrincipalAccount}/*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [var.firehose_backup_org_id]
    }
  }

  statement {
    sid       = "DenyAllDelete"
    effect    = "Deny"
    actions   = ["s3:DeleteObjectVersion", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.firehose_backup.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id
  policy = data.aws_iam_policy_document.firehose_backup.json
}

