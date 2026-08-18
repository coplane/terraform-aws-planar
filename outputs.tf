output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_execution.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = var.ignore_task_definition_changes ? aws_ecs_service.ignore_task_definition[0].name : aws_ecs_service.main[0].name
}

output "ecs_task_definition_family" {
  description = "ECS task definition family used by application deployment pipelines"
  value       = aws_ecs_task_definition.main.family
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "rds_cluster_endpoint" {
  description = "RDS cluster endpoint"
  value       = aws_rds_cluster.main.endpoint
  sensitive   = true
}

output "rds_cluster_reader_endpoint" {
  description = "RDS cluster reader endpoint"
  value       = aws_rds_cluster.main.reader_endpoint
  sensitive   = true
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.app_bucket.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.app_bucket.arn
}

output "db_secret_arn" {
  description = "ARN of the database secret"
  value       = aws_rds_cluster.main.master_user_secret[0].secret_arn
  sensitive   = true
}

output "custom_secret_arn" {
  description = "ARN of the custom secret"
  value       = aws_secretsmanager_secret.custom_secret.arn
  sensitive   = true
}

output "certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = aws_acm_certificate.main.arn
}

output "domain_name" {
  description = "Full domain name for the application"
  value       = local.full_domain_name
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "container_image_url" {
  description = "Full container image URL being used"
  value       = var.repository_name != null ? "${aws_ecr_repository.main[0].repository_url}:latest" : "${var.container_registry_url}/${var.container_image_name}:${var.container_image_tag}"
}

output "registry_credentials_secret_arn" {
  description = "ARN of the registry credentials secret"
  value       = var.container_registry_username != null && var.container_registry_password != null ? aws_secretsmanager_secret.registry_credentials[0].arn : null
  sensitive   = true
}
