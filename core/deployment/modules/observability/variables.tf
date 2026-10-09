variable "amp_workspace_alias" {
  description = "Alias for the Amazon Managed Prometheus workspace."
  type        = string
}

variable "amg_workspace_name" {
  description = "Name for the Amazon Managed Grafana workspace."
  type        = string
}

variable "grafana_version" {
  description = "Amazon Managed Grafana version."
  type        = string
  default     = "12.4"
}

variable "amg_query_role_name" {
  description = "Name of the IAM role used by the AMG workspace to query AMP."
  type        = string
  default     = "trongpq-amg-amp-query"
}

variable "sso_instance_arn" {
  description = "ARN of the AWS IAM Identity Center (SSO) instance. Pending cloud engineer confirmation."
  type        = string
  default     = ""
}