# Planar on AWS

An opinionated Terraform module for deploying a Planar application into a customer-managed AWS account.

The module owns the application infrastructure. The customer owns the AWS account, Terraform root configuration and state, networking, DNS zone, container image, and deployment pipeline.

## What this module creates

| Area | Resources |
| --- | --- |
| Compute | ECS Fargate cluster, task definition, service, and CloudWatch log groups |
| Networking | Application Load Balancer, target group, listeners, and security groups |
| Data | Aurora PostgreSQL Serverless v2 and an encrypted, versioned S3 bucket |
| Identity | ECS task and execution roles with Planar runtime permissions |
| DNS and TLS | Route 53 application record and DNS-validated ACM certificate |
| Observability | AWS Distro for OpenTelemetry sidecar and optional ECS container metrics |
| Edge security | Optional AWS WAF managed rules or an existing WAF web ACL |

## Usage

The following example deploys Planar into existing public and private subnets. It assumes the customer deploys application revisions through a separate CI/CD pipeline.

Pin the module to a released version. Do not reference `main` from production configurations.

```hcl
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
  source = "git::https://github.com/coplane/planar-deploy-infra-aws.git?ref=v0.10.0"

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
```

The application will be available at `https://claims-prod.apps.example.com` after DNS and certificate validation complete.

## Prerequisites

The calling configuration must provide:

- An AWS provider configured for the target account and region.
- A VPC with DNS support enabled.
- At least two private subnets for ECS and Aurora. They need outbound access to AWS APIs, WorkOS, and the Planar telemetry endpoint through NAT gateways or suitable VPC endpoints.
- Public subnets for an internet-facing load balancer, or private subnets with `alb_internal = true` for an internal load balancer.
- A Route 53 hosted zone matching `base_domain_name`.
- A container image that the ECS execution role can pull.
- WorkOS client and organization IDs supplied during onboarding.
- A Secrets Manager secret containing the Planar telemetry token as its entire secret string.
- A Terraform execution role permitted to create the resources listed above, including IAM roles and policies.

Terraform state and state locking are intentionally outside this module. Configure them in the customer-owned root module.

## Deployment ownership

The `ignore_task_definition_changes` input determines whether Terraform or application CI/CD controls the task-definition revision running on the ECS service.

| Value | Deployment owner | Behavior |
| --- | --- | --- |
| `false` | Terraform | Changes to the module's task definition update the ECS service. Use `container_image_tag` to deploy application versions. |
| `true` | External CI/CD | Terraform manages the task-definition specification but ignores service revision drift created by application deployments. |

Set `ignore_task_definition_changes = true` when application CI/CD deploys images independently of Terraform. Choose the mode before the initial apply. Changing it for an existing deployment changes the Terraform resource address of the ECS service and may require state migration.

An external deployment pipeline must:

1. Read `ecs_cluster_name`, `ecs_service_name`, and `ecs_task_definition_family` from module outputs or equivalent deployment configuration.
2. Fetch the latest active revision in that task-definition family, not only the revision currently attached to the service.
3. Replace the `planar-app` container image without discarding Terraform-managed environment variables, secrets, roles, or sidecars.
4. Register the resulting task definition and update the ECS service.
5. Wait for service stability and fail the deployment if the ECS circuit breaker rolls it back.

Do not maintain an independent task-definition JSON document in the application repository. It can silently overwrite infrastructure changes introduced by a module upgrade.

## Telemetry credentials

`telemetry_token_secret_arn` is the preferred input. ECS retrieves the token at task startup and the module grants `secretsmanager:GetSecretValue` to the ECS execution role for that secret only.

The legacy `telemetry_token` input remains available for compatibility, but its value becomes part of the task-definition environment and Terraform state. Do not use it for new customer-managed deployments.

If the secret uses a customer-managed KMS key, the key policy and an additional IAM policy must allow the ECS execution role to call `kms:Decrypt`. The module exports `ecs_execution_role_arn` for that integration.

## Networking and DNS

By default, the load balancer is internet-facing and must use public subnets. ECS tasks and Aurora run in the private subnets supplied through `subnets` and receive no public IP addresses.

Set `alb_internal = true` to use an internal load balancer. In that mode, `alb_subnets` may also reference private subnets with appropriate routing.

The module creates an ACM certificate and Route 53 record for:

```text
{app_name}-{stage}.{base_domain_name}
```

The hosted zone itself remains customer-managed. The [`create_dns_hosted_zone`](examples/create_dns_hosted_zone) example is available when a delegated zone is needed.

## Container registries

The module supports three image sources:

- Existing ECR: set `container_registry_url` and `container_image_name`.
- Another registry: additionally set `container_registry_username` and `container_registry_password` when authentication is required.
- Module-managed ECR: set `repository_name`. The initial image must be available before the ECS service can become healthy.

Customer-managed ECR is recommended for BYOC deployments because image lifecycle and deployment permissions remain in the customer's infrastructure repository.

## Security notes

- ECS tasks and Aurora are placed in private subnets.
- The S3 bucket blocks public access, requires TLS, enables versioning, and encrypts objects at rest.
- Aurora storage is encrypted and its master password is managed by Secrets Manager.
- `create_waf = true` attaches the default AWS managed rule groups. Alternatively, provide `waf_web_acl_arn`.
- The ECS task role includes Bedrock model invocation permissions. Review the effective policy against the customer's AWS security requirements.
- ALB access logging is optional and requires a customer-provided S3 bucket.

## Examples

- [`with-existing-vpc`](examples/with-existing-vpc): customer-managed networking, ECR, telemetry secret, and application CI/CD.
- [`with-new-vpc`](examples/with-new-vpc): evaluation deployment using the included VPC submodule.
- [`create_dns_hosted_zone`](examples/create_dns_hosted_zone): delegated Route 53 hosted zone for a Planar tenant domain.

The checked-in examples use relative module sources so they validate against the current repository. Customer configurations should use the version-pinned Git source shown above.

## Upgrades

Use an immutable release tag and review the [changelog](CHANGELOG.md) before updating it. Run `terraform plan` in every environment before applying a new module version. Application deployment mode changes deserve particular care because of the ECS service state considerations described above.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_null"></a> [null](#provider\_null) | >= 3.2 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.1 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | Application name | `string` | n/a | yes |
| <a name="input_base_domain_name"></a> [base\_domain\_name](#input\_base\_domain\_name) | Base domain name for Route53 hosted zone | `string` | n/a | yes |
| <a name="input_hosted_zone_id"></a> [hosted\_zone\_id](#input\_hosted\_zone\_id) | Route53 hosted zone ID for DNS records and ACM certificate validation | `string` | n/a | yes |
| <a name="input_stage"></a> [stage](#input\_stage) | Stage/environment name | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | List of private subnet IDs for ECS tasks | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where resources will be created | `string` | n/a | yes |
| <a name="input_workos_client_id"></a> [workos\_client\_id](#input\_workos\_client\_id) | WorkOS client ID | `string` | n/a | yes |
| <a name="input_workos_org_id"></a> [workos\_org\_id](#input\_workos\_org\_id) | WorkOS organization ID | `string` | n/a | yes |
| <a name="input_alb_access_logs_bucket"></a> [alb\_access\_logs\_bucket](#input\_alb\_access\_logs\_bucket) | S3 bucket name for ALB access logs (required when alb\_access\_logs\_enabled = true) | `string` | `null` | no |
| <a name="input_alb_access_logs_enabled"></a> [alb\_access\_logs\_enabled](#input\_alb\_access\_logs\_enabled) | Enable ALB access logging (requires alb\_access\_logs\_bucket) | `bool` | `false` | no |
| <a name="input_alb_access_logs_prefix"></a> [alb\_access\_logs\_prefix](#input\_alb\_access\_logs\_prefix) | S3 key prefix for ALB access logs | `string` | `null` | no |
| <a name="input_alb_internal"></a> [alb\_internal](#input\_alb\_internal) | Whether the ALB should be internal (not accessible from internet) | `bool` | `false` | no |
| <a name="input_alb_subnets"></a> [alb\_subnets](#input\_alb\_subnets) | List of public subnet IDs for the ALB (required for internet-facing ALBs) | `list(string)` | `null` | no |
| <a name="input_aurora_max_capacity"></a> [aurora\_max\_capacity](#input\_aurora\_max\_capacity) | Maximum Aurora Serverless v2 capacity (ACUs) | `number` | `2` | no |
| <a name="input_aurora_min_capacity"></a> [aurora\_min\_capacity](#input\_aurora\_min\_capacity) | Minimum Aurora Serverless v2 capacity (ACUs) | `number` | `0.5` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-west-2"` | no |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Number of days to retain backups | `number` | `7` | no |
| <a name="input_container_cpu"></a> [container\_cpu](#input\_container\_cpu) | CPU units for the container (1024 = 1 vCPU) | `number` | `2048` | no |
| <a name="input_container_image_name"></a> [container\_image\_name](#input\_container\_image\_name) | Full image path including owner/repo (e.g., owner/repo or username/repo) | `string` | `null` | no |
| <a name="input_container_image_tag"></a> [container\_image\_tag](#input\_container\_image\_tag) | Image tag or digest to deploy | `string` | `"latest"` | no |
| <a name="input_container_memory"></a> [container\_memory](#input\_container\_memory) | Memory for the container in MB | `number` | `4096` | no |
| <a name="input_container_registry_password"></a> [container\_registry\_password](#input\_container\_registry\_password) | Password or token for container registry authentication. Required only for private registries. | `string` | `null` | no |
| <a name="input_container_registry_url"></a> [container\_registry\_url](#input\_container\_registry\_url) | Base URL of the private container registry (e.g., ghcr.io, docker.io, registry.example.com) | `string` | `null` | no |
| <a name="input_container_registry_username"></a> [container\_registry\_username](#input\_container\_registry\_username) | Username for container registry authentication. Required only for private registries. | `string` | `null` | no |
| <a name="input_cors_allowed_origins"></a> [cors\_allowed\_origins](#input\_cors\_allowed\_origins) | List of allowed origins for S3 CORS | `list(string)` | <pre>[<br/>  "https://staging.coplane.com",<br/>  "https://staging.coplane.com/",<br/>  "https://app.coplane.com",<br/>  "https://app.coplane.com/"<br/>]</pre> | no |
| <a name="input_create_waf"></a> [create\_waf](#input\_create\_waf) | Create a WAFv2 Web ACL with AWS managed rules (CommonRuleSet, KnownBadInputsRuleSet, SQLiRuleSet) and attach it to the ALB. Ignored if waf\_web\_acl\_arn is provided. | `bool` | `false` | no |
| <a name="input_custom_environment_variables"></a> [custom\_environment\_variables](#input\_custom\_environment\_variables) | Map of custom environment variables to add to the ECS task | `map(string)` | `{}` | no |
| <a name="input_customer_name"></a> [customer\_name](#input\_customer\_name) | Customer name for OTel resource attributes. Defaults to app\_name if not set. | `string` | `null` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Desired number of running tasks | `number` | `1` | no |
| <a name="input_ecs_container_insights"></a> [ecs\_container\_insights](#input\_ecs\_container\_insights) | ECS Container Insights setting for the cluster (disabled, enabled, enhanced) | `string` | `"disabled"` | no |
| <a name="input_ecs_log_retention_days"></a> [ecs\_log\_retention\_days](#input\_ecs\_log\_retention\_days) | CloudWatch log retention (days) for app ECS logs | `number` | `14` | no |
| <a name="input_enable_ecs_container_metrics"></a> [enable\_ecs\_container\_metrics](#input\_enable\_ecs\_container\_metrics) | Enable the ECS container metrics receiver in the OTEL collector. When enabled, exports CPU, memory, network I/O, and storage metrics at both task and container level. | `bool` | `false` | no |
| <a name="input_enable_logs_pipeline"></a> [enable\_logs\_pipeline](#input\_enable\_logs\_pipeline) | Enable an OTel Collector logs pipeline that exports app OTLP logs to the telemetry gateway. Uses the same endpoint and token as metrics/traces. | `bool` | `false` | no |
| <a name="input_ignore_task_definition_changes"></a> [ignore\_task\_definition\_changes](#input\_ignore\_task\_definition\_changes) | Whether changes to the ECS service task\_definition should be ignored. Enable when an external CI/CD pipeline (not Terraform) deploys new task definition revisions. | `bool` | `false` | no |
| <a name="input_import_image_to_ecr"></a> [import\_image\_to\_ecr](#input\_import\_image\_to\_ecr) | Whether to import the source image to the created ECR repository | `bool` | `false` | no |
| <a name="input_metrics_endpoint"></a> [metrics\_endpoint](#input\_metrics\_endpoint) | OTLP HTTP base URL for the metrics exporter (Coplane telemetry gateway). Required when telemetry\_enabled = true. | `string` | `"https://telemetry.coplane.dev"` | no |
| <a name="input_otel_log_retention_days"></a> [otel\_log\_retention\_days](#input\_otel\_log\_retention\_days) | CloudWatch log retention (days) for OTEL collector logs | `number` | `7` | no |
| <a name="input_rds_monitoring_interval"></a> [rds\_monitoring\_interval](#input\_rds\_monitoring\_interval) | RDS enhanced monitoring interval in seconds (0 to disable) | `number` | `60` | no |
| <a name="input_rds_performance_insights_enabled"></a> [rds\_performance\_insights\_enabled](#input\_rds\_performance\_insights\_enabled) | Enable RDS Performance Insights | `bool` | `true` | no |
| <a name="input_repository_name"></a> [repository\_name](#input\_repository\_name) | Name of the ECR repository. If provided, a private ECR repository will be created. | `string` | `null` | no |
| <a name="input_source_image"></a> [source\_image](#input\_source\_image) | Public Docker image to import into ECR (e.g. nginx:latest) | `string` | `"ghcr.io/coplane/planar-demo-public:latest"` | no |
| <a name="input_telemetry_enabled"></a> [telemetry\_enabled](#input\_telemetry\_enabled) | Add an OTel Collector sidecar for metrics and log forwarding. Disable to opt out. | `bool` | `true` | no |
| <a name="input_telemetry_token"></a> [telemetry\_token](#input\_telemetry\_token) | Bearer token for authenticating with the Coplane telemetry gateway. Ignored when telemetry\_token\_secret\_arn is set. | `string` | `null` | no |
| <a name="input_telemetry_token_secret_arn"></a> [telemetry\_token\_secret\_arn](#input\_telemetry\_token\_secret\_arn) | ARN of a Secrets Manager secret containing the Coplane telemetry bearer token. Preferred over telemetry\_token. | `string` | `null` | no |
| <a name="input_waf_managed_rule_groups"></a> [waf\_managed\_rule\_groups](#input\_waf\_managed\_rule\_groups) | Additional AWS managed rule groups to append to the default WAF rules. | <pre>list(object({<br/>    name   = string<br/>    metric = string<br/>    vendor = optional(string, "AWS")<br/>  }))</pre> | `[]` | no |
| <a name="input_waf_web_acl_arn"></a> [waf\_web\_acl\_arn](#input\_waf\_web\_acl\_arn) | ARN of an existing WAFv2 Web ACL to associate with the ALB. Takes precedence over create\_waf. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_region"></a> [aws\_region](#output\_aws\_region) | AWS region where resources are deployed |
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | ARN of the SSL certificate |
| <a name="output_container_image_url"></a> [container\_image\_url](#output\_container\_image\_url) | Full container image URL being used |
| <a name="output_custom_secret_arn"></a> [custom\_secret\_arn](#output\_custom\_secret\_arn) | ARN of the custom secret |
| <a name="output_db_secret_arn"></a> [db\_secret\_arn](#output\_db\_secret\_arn) | ARN of the database secret |
| <a name="output_domain_name"></a> [domain\_name](#output\_domain\_name) | Full domain name for the application |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | Name of the ECS cluster |
| <a name="output_ecs_execution_role_arn"></a> [ecs\_execution\_role\_arn](#output\_ecs\_execution\_role\_arn) | ARN of the ECS task execution role |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | Name of the ECS service |
| <a name="output_ecs_task_definition_family"></a> [ecs\_task\_definition\_family](#output\_ecs\_task\_definition\_family) | ECS task definition family used by application deployment pipelines |
| <a name="output_ecs_task_role_arn"></a> [ecs\_task\_role\_arn](#output\_ecs\_task\_role\_arn) | ARN of the ECS task role |
| <a name="output_load_balancer_dns_name"></a> [load\_balancer\_dns\_name](#output\_load\_balancer\_dns\_name) | DNS name of the load balancer |
| <a name="output_load_balancer_zone_id"></a> [load\_balancer\_zone\_id](#output\_load\_balancer\_zone\_id) | Zone ID of the load balancer |
| <a name="output_rds_cluster_endpoint"></a> [rds\_cluster\_endpoint](#output\_rds\_cluster\_endpoint) | RDS cluster endpoint |
| <a name="output_rds_cluster_reader_endpoint"></a> [rds\_cluster\_reader\_endpoint](#output\_rds\_cluster\_reader\_endpoint) | RDS cluster reader endpoint |
| <a name="output_registry_credentials_secret_arn"></a> [registry\_credentials\_secret\_arn](#output\_registry\_credentials\_secret\_arn) | ARN of the registry credentials secret |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | ARN of the S3 bucket |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | Name of the S3 bucket |
<!-- END_TF_DOCS -->

## Development

Regenerate the requirements, inputs, and outputs after changing the module API:

```shell
terraform-docs .
```

## Support

Contact `support@coplane.com` for onboarding and support.

## License

Apache License 2.0
