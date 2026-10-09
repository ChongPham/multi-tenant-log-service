output "amp_workspace_id" {
  description = "ID of the Amazon Managed Prometheus workspace."
  value       = aws_prometheus_workspace.this.id
}

output "amp_workspace_arn" {
  description = "ARN of the Amazon Managed Prometheus workspace."
  value       = aws_prometheus_workspace.this.arn
}

output "amp_endpoint" {
  description = "Base AMP endpoint (Grafana data source URL)."
  value       = aws_prometheus_workspace.this.prometheus_endpoint
}

output "amp_query_url" {
  description = "AMP query endpoint for Grafana."
  value       = "${aws_prometheus_workspace.this.prometheus_endpoint}api/v1/query"
}

output "amg_workspace_id" {
  description = "ID of the Amazon Managed Grafana workspace."
  value       = aws_grafana_workspace.this.id
}

output "amg_workspace_endpoint" {
  description = "User-facing endpoint of the AMG workspace."
  value       = aws_grafana_workspace.this.endpoint
}

output "amg_query_role_arn" {
  description = "ARN of the IAM role the AMG workspace uses to query AMP."
  value       = aws_iam_role.amg_query.arn
}

output "grafana_service_account_token" {
  description = "Service account token for Grafana provider."
  value       = aws_grafana_workspace_service_account_token.terraform.key
  sensitive   = true
}
