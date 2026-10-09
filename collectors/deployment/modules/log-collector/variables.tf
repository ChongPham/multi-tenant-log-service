variable "cluster_id" {
  description = "ID (ARN) of the shared ECS cluster."
  type        = string
}

variable "service_name" {
  description = "ECS service and task definition name."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID. Provided externally."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the internet-facing NLB."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) > 0
    error_message = "Provide at least one public subnet ID for the NLB."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks. NAT egress is required by the current container startup configuration."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) > 0
    error_message = "Provide at least one private subnet ID for ECS tasks."
  }
}

variable "config_prefix" {
  description = "S3 key prefix under config_bucket_name that all vector_config_files are uploaded under, and that the container syncs from at boot."
  type        = string
  default     = "log-collector"
}

variable "vector_config_files" {
  description = <<-EOT
    Map of filename => rendered Vector config content. Each entry is uploaded
    to s3://config_bucket_name/config_prefix/<filename> and the container
    syncs the whole prefix down and launches Vector with --config-dir, so
    Vector merges every file into one runtime topology. One file should
    define the shared source + sink (see collectors/config/log-collector/base.yaml);
    the rest are one per onboarded tenant.
  EOT
  type        = map(string)
}

variable "access_key_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the Firehose access key."
  type        = string
}

variable "config_bucket_name" {
  description = "S3 bucket for Vector config."
  type        = string
}

variable "amp_workspace_arn" {
  description = "ARN of the AMP workspace for IAM permissions."
  type        = string
}

variable "vector_image_tag" {
  description = "Docker tag for the Vector image. Must support the aws_kinesis_firehose source's `common_attributes` and `access_keys` (plural) options."
  type        = string
  default     = "0.58.0-debian"
}
