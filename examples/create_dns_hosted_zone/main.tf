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

module "dns_zone" {
  source = "../../modules/dns"

  tenant_id     = "example-tenant"
  domain_suffix = "example.com"
}

output "hosted_zone_id" {
  description = "ID of the delegated Route 53 hosted zone"
  value       = module.dns_zone.zone_id
}

output "name_servers" {
  description = "Name servers to configure in the parent DNS zone"
  value       = module.dns_zone.name_servers
}
