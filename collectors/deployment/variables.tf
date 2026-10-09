# Values passed by GitHub Actions — do not modify
variable "target_environment" {
  type = string
}

variable "target_stage" {
  type = string
}

variable "core_state_bucket" {
  description = "S3 bucket holding the core Terraform state."
  type        = string
}

variable "core_state_key" {
  description = "S3 key for the core Terraform state file."
  type        = string
  default     = "core/deployment/terraform.tfstate"
}

variable "core_state_region" {
  description = "AWS region of the core state bucket."
  type        = string
  default     = "eu-central-1"
}

# Networking (provided by cloud engineer — never create these in Terraform)
variable "vpc_id" {
  description = "VPC ID. Provided externally."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the internet-facing NLB, with a route to an Internet Gateway."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) > 0
    error_message = "Provide at least one public subnet ID for the NLB."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks, with NAT egress for public images, package downloads and AWS APIs."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) > 0
    error_message = "Provide at least one private subnet ID for ECS tasks."
  }
}

# Shared ECS cluster
variable "cluster_name" {
  description = "Name of the shared ECS cluster for all collectors."
  type        = string
}

# Log collector (multi-tenant log-forwarding ingestion -- hosts every
# onboarded log-forwarding tenant, including Chromeleon)
variable "log_collector_service_name" {
  description = "ECS service name for the shared multi-tenant log collector."
  type        = string
}