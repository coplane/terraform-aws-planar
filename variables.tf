variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}


variable "app_name" {
  description = "Application name"
  type        = string
}

variable "customer_name" {
  description = "Customer name for OTel resource attributes. Defaults to app_name if not set."
  type        = string
  default     = null
}

variable "stage" {
  description = "Stage/environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.stage)
    error_message = "Stage must be one of: dev, staging, prod."
  }
}

variable "base_domain_name" {
  description = "Base domain name for Route53 hosted zone"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for DNS records and ACM certificate validation"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "subnets" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "alb_subnets" {
  description = "List of public subnet IDs for the ALB (required for internet-facing ALBs)"
  type        = list(string)
  default     = null
}

variable "container_cpu" {
  description = "CPU units for the container (1024 = 1 vCPU)"
  type        = number
  default     = 2048
}

variable "container_memory" {
  description = "Memory for the container in MB"
  type        = number
  default     = 4096
}

variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 1
}

variable "aurora_min_capacity" {
  description = "Minimum Aurora Serverless v2 capacity (ACUs)"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum Aurora Serverless v2 capacity (ACUs)"
  type        = number
  default     = 2.0
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for S3 CORS"
  type        = list(string)
  default = [
    "https://staging.coplane.com",
    "https://staging.coplane.com/",
    "https://app.coplane.com",
    "https://app.coplane.com/"
  ]
}

variable "container_registry_url" {
  description = "Base URL of the private container registry (e.g., ghcr.io, docker.io, registry.example.com)"
  type        = string
  default     = null
}

variable "container_image_name" {
  description = "Full image path including owner/repo (e.g., owner/repo or username/repo)"
  type        = string
  default     = null
}

variable "container_image_tag" {
  description = "Image tag or digest to deploy"
  type        = string
  default     = "latest"
}

variable "container_registry_username" {
  description = "Username for container registry authentication. Required only for private registries."
  type        = string
  default     = null
}

variable "container_registry_password" {
  description = "Password or token for container registry authentication. Required only for private registries."
  type        = string
  sensitive   = true
  default     = null
}

variable "alb_internal" {
  description = "Whether the ALB should be internal (not accessible from internet)"
  type        = bool
  default     = false
}

variable "alb_access_logs_enabled" {
  description = "Enable ALB access logging (requires alb_access_logs_bucket)"
  type        = bool
  default     = false
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket name for ALB access logs (required when alb_access_logs_enabled = true)"
  type        = string
  default     = null

  validation {
    condition     = !var.alb_access_logs_enabled || var.alb_access_logs_bucket != null
    error_message = "alb_access_logs_bucket is required when alb_access_logs_enabled = true."
  }
}

variable "alb_access_logs_prefix" {
  description = "S3 key prefix for ALB access logs"
  type        = string
  default     = null
}

variable "create_waf" {
  description = "Create a WAFv2 Web ACL with AWS managed rules (CommonRuleSet, KnownBadInputsRuleSet, SQLiRuleSet) and attach it to the ALB. Ignored if waf_web_acl_arn is provided."
  type        = bool
  default     = false
}

variable "waf_managed_rule_groups" {
  description = "Additional AWS managed rule groups to append to the default WAF rules."
  type = list(object({
    name   = string
    metric = string
    vendor = optional(string, "AWS")
  }))
  default = []
}

variable "waf_web_acl_arn" {
  description = "ARN of an existing WAFv2 Web ACL to associate with the ALB. Takes precedence over create_waf."
  type        = string
  default     = null
}

variable "repository_name" {
  description = "Name of the ECR repository. If provided, a private ECR repository will be created."
  type        = string
  default     = null
}

variable "source_image" {
  description = "Public Docker image to import into ECR (e.g. nginx:latest)"
  type        = string
  default     = "ghcr.io/coplane/planar-demo-public:latest"
}

variable "import_image_to_ecr" {
  description = "Whether to import the source image to the created ECR repository"
  type        = bool
  default     = false
}

variable "workos_client_id" {
  description = "WorkOS client ID"
  type        = string
}

variable "workos_org_id" {
  description = "WorkOS organization ID"
  type        = string
}

variable "custom_environment_variables" {
  description = "Map of custom environment variables to add to the ECS task"
  type        = map(string)
  default     = {}
}

variable "telemetry_enabled" {
  description = "Add an OTel Collector sidecar for metrics and log forwarding. Disable to opt out."
  type        = bool
  default     = true
}

variable "enable_ecs_container_metrics" {
  description = "Enable the ECS container metrics receiver in the OTEL collector. When enabled, exports CPU, memory, network I/O, and storage metrics at both task and container level."
  type        = bool
  default     = false
}

variable "ecs_container_insights" {
  description = "ECS Container Insights setting for the cluster (disabled, enabled, enhanced)"
  type        = string
  default     = "disabled"

  validation {
    condition     = contains(["disabled", "enabled", "enhanced"], var.ecs_container_insights)
    error_message = "ecs_container_insights must be one of: disabled, enabled, enhanced."
  }
}

variable "metrics_endpoint" {
  description = "OTLP HTTP base URL for the metrics exporter (Coplane telemetry gateway). Required when telemetry_enabled = true."
  type        = string
  default     = "https://telemetry.coplane.dev"

  validation {
    condition     = !var.telemetry_enabled || var.metrics_endpoint != null
    error_message = "metrics_endpoint is required when telemetry_enabled = true."
  }
}

variable "enable_logs_pipeline" {
  description = "Enable an OTel Collector logs pipeline that exports app OTLP logs to the telemetry gateway. Uses the same endpoint and token as metrics/traces."
  type        = bool
  default     = false
}

variable "ecs_log_retention_days" {
  description = "CloudWatch log retention (days) for app ECS logs"
  type        = number
  default     = 14
}

variable "otel_log_retention_days" {
  description = "CloudWatch log retention (days) for OTEL collector logs"
  type        = number
  default     = 7
}

variable "ignore_task_definition_changes" {
  description = "Whether changes to the ECS service task_definition should be ignored. Enable when an external CI/CD pipeline (not Terraform) deploys new task definition revisions."
  type        = bool
  default     = false
}

variable "rds_performance_insights_enabled" {
  description = "Enable RDS Performance Insights"
  type        = bool
  default     = true
}

variable "rds_monitoring_interval" {
  description = "RDS enhanced monitoring interval in seconds (0 to disable)"
  type        = number
  default     = 60
}

variable "telemetry_token" {
  description = "Bearer token for authenticating with the Coplane telemetry gateway. Provided during onboarding."
  type        = string
  sensitive   = true
  default     = null
}

variable "otel_database_metrics_enabled" {
  description = "Enable OTel postgres receivers (postgresql + sqlquery against pg_stat_statements). Provisions an otel_monitor password in Secrets Manager and attaches a cluster parameter group enabling pg_stat_statements. Transition from false to true requires a one-time database reboot for shared_preload_libraries to take effect. The planar app must also set otel.database_metrics.enabled = true in its config to bootstrap the matching DB role."
  type        = bool
  default     = false
}
