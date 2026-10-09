#  tạo AMP workspace. Đây là nơi lưu và cung cấp API để truy vấn metrics. 
# Chromeleon gửi metrics đến workspace này qua sigv4-proxy; 
# quyền ghi aps:RemoteWrite được cấu hình riêng trong module Chromeleon collector.
resource "aws_prometheus_workspace" "this" {
  alias = var.amp_workspace_alias
}

# tạo tài liệu policy cho phép dịch vụ Amazon Managed Grafana (AMG) assume IAM role. Đây là policy document, không tự tạo một resource AWS.
data "aws_iam_policy_document" "amg_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["grafana.amazonaws.com"]
    }
  }
}

# định nghĩa các quyền AMG cần để truy vấn AMP, như đọc metrics, series, labels và metadata. Đây cũng là policy document.
data "aws_iam_policy_document" "amg_amp_query" {
  statement {
    actions = [
      "aps:QueryMetrics",
      "aps:GetSeries",
      "aps:GetLabels",
      "aps:GetMetricMetadata",
      "aps:ListWorkspaces",
      "aps:DescribeWorkspace",
    ]
    resources = ["*"]
  }
}

# IAM role mà Grafana workspace dùng khi truy vấn AMP.
resource "aws_iam_role" "amg_query" {
  name               = var.amg_query_role_name
  assume_role_policy = data.aws_iam_policy_document.amg_assume_role.json
}

# gắn các quyền truy vấn AMP vào role trên. Hiện policy đặt resources = ["*"], nên quyền không giới hạn vào riêng một workspace AMP.
resource "aws_iam_role_policy" "amg_amp_query" {
  name   = "amp-query"
  role   = aws_iam_role.amg_query.id
  policy = data.aws_iam_policy_document.amg_amp_query.json
}

#  tạo AMG workspace làm giao diện dashboard và truy vấn metrics. Cấu hình hiện tại dùng AWS_SSO để xác thực và gắn query role ở trên.

# aws_iam_role.amg_query tạo IAM role.
# aws_grafana_workspace.this gán role đó cho AMG bằng:
# Khi AMG cần truy vấn AMP, dịch vụ Grafana được phép assume role này theo trust policy amg_assume_role.
# Role nhận quyền được khai báo trong amg_amp_query, rồi AMG dùng các quyền đó để gọi AMP.
resource "aws_grafana_workspace" "this" {
  name                     = var.amg_workspace_name
  grafana_version          = var.grafana_version
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "CUSTOMER_MANAGED"
  role_arn                 = aws_iam_role.amg_query.arn
  data_sources             = ["PROMETHEUS"]
}

# tạo service account tên terraform, có quyền Grafana ADMIN. Đây là tài khoản kỹ thuật dành cho Terraform, 
# không phải tài khoản người dùng dashboard.
# Mục đích là để Terraform có thể quản lý các resource bên trong Grafana, ví dụ như dashboards, data sources, alert channels, v.v.
resource "aws_grafana_workspace_service_account" "terraform" {
  name         = "terraform"
  grafana_role = "ADMIN"
  workspace_id = aws_grafana_workspace.this.id
}


# AMG service account tokens max out at 30 days (seconds_to_live below); this
# forces a fresh token before that, so the scheduled daily apply keeps it
# valid without anyone manually running `terraform apply -replace=...`.
# tạo mốc luân phiên token mỗi 25 ngày
resource "time_rotating" "grafana_token_rotation" {
  rotation_days = 25
}

# tạo token cho service account Terraform. Token được thay mới theo mốc luân phiên để provider Grafana dùng khi Terraform quản lý cấu hình bên trong Grafana.
resource "aws_grafana_workspace_service_account_token" "terraform" {
  name               = "terraform"
  service_account_id = aws_grafana_workspace_service_account.terraform.service_account_id
  seconds_to_live    = 2592000
  workspace_id       = aws_grafana_workspace.this.id

  lifecycle {
    replace_triggered_by = [time_rotating.grafana_token_rotation]
  }
}
