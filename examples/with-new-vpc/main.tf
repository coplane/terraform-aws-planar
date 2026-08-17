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

module "vpc" {
  source = "../../modules/vpc"

  name       = "planar-evaluation"
  cidr_block = "10.0.0.0/16"

  availability_zone_count = 2
  single_nat_gateway      = true

  tags = {
    Environment = "evaluation"
    ManagedBy   = "terraform"
  }
}

module "planar" {
  source = "../../"

  app_name         = "evaluation"
  customer_name    = "example-customer"
  stage            = "dev"
  aws_region       = "us-west-2"
  base_domain_name = "apps.example.com"
  hosted_zone_id   = "Z0123456789ABCDEF"

  vpc_id      = module.vpc.vpc_id
  subnets     = module.vpc.private_subnet_ids
  alb_subnets = module.vpc.public_subnet_ids

  container_registry_url = "ghcr.io"
  container_image_name   = "coplane/planar-demo-public"
  container_image_tag    = "latest"

  workos_client_id = "client_..."
  workos_org_id    = "org_..."

  telemetry_token_secret_arn = data.aws_secretsmanager_secret.telemetry_token.arn
  create_waf                 = true
}

output "application_url" {
  description = "HTTPS URL of the Planar application"
  value       = "https://${module.planar.domain_name}"
}
