terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

data "aws_secretsmanager_secret" "telemetry_token" {
  name = "planar-telemetry-token"
}

module "planar" {
  source = "../../"

  app_name         = "claims"
  customer_name    = "example-customer"
  stage            = "prod"
  aws_region       = "us-west-2"
  base_domain_name = "apps.example.com"
  hosted_zone_id   = "Z0123456789ABCDEF"

  vpc_id      = "vpc-0123456789abcdef0"
  subnets     = ["subnet-private-a", "subnet-private-b"]
  alb_subnets = ["subnet-public-a", "subnet-public-b"]

  container_registry_url = "123456789012.dkr.ecr.us-west-2.amazonaws.com"
  container_image_name   = "planar"
  container_image_tag    = "bootstrap"

  workos_client_id = "client_..."
  workos_org_id    = "org_..."

  telemetry_token_secret_arn   = data.aws_secretsmanager_secret.telemetry_token.arn
  enable_ecs_container_metrics = true
  enable_logs_pipeline         = true

  ignore_task_definition_changes = true
  create_waf                     = true
}

output "application_url" {
  description = "HTTPS URL of the Planar application"
  value       = "https://${module.planar.domain_name}"
}

output "deployment" {
  description = "ECS identifiers consumed by the application deployment pipeline"
  value = {
    cluster                = module.planar.ecs_cluster_name
    service                = module.planar.ecs_service_name
    task_definition_family = module.planar.ecs_task_definition_family
  }
}
