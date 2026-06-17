output "instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.llm[*].id
}

output "instance_public_ips" {
  description = "Public IP addresses of LLM instances"
  value       = aws_instance.llm[*].public_ip
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = var.enable_alb ? aws_lb.llm[0].dns_name : null
}

output "api_endpoint" {
  description = "Primary API endpoint URL"
  value       = var.enable_alb ? "http://${aws_lb.llm[0].dns_name}" : "http://${aws_instance.llm[0].public_ip}:8000"
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.llm.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.llm_api.id
}
