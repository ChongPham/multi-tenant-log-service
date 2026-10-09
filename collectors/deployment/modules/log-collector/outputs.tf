output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "nlb_dns_name" {
  description = "DNS name of the NLB (use for Firehose HTTP endpoint configuration)."
  value       = aws_lb.this.dns_name
}

output "nlb_arn" {
  description = "ARN of the NLB."
  value       = aws_lb.this.arn
}
