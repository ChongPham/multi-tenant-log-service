output "cluster_name" {
  description = "Shared ECS cluster name."
  value       = aws_ecs_cluster.collectors.name
}

output "log_collector_service_name" {
  description = "Log collector ECS service name."
  value       = module.log_collector.service_name
}

output "log_collector_nlb_dns_name" {
  description = "Shared multi-tenant log collector NLB DNS name (point onboarding stacks' TrongpqIngestionUrl at this)."
  value       = module.log_collector.nlb_dns_name
}
