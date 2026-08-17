locals {
  otel_base_config = var.telemetry_enabled ? templatefile("${path.module}/templates/otel_collector.yaml.tftpl", {
    enable_ecs_container_metrics = var.enable_ecs_container_metrics
    enable_logs_pipeline         = var.enable_logs_pipeline
    metrics_endpoint             = "$${env:METRICS_ENDPOINT}"
    telemetry_token              = "$${env:TELEMETRY_TOKEN}"
    service_name                 = var.app_name
    customer_name                = coalesce(var.customer_name, var.app_name)
    stage                        = var.stage
  }) : null

  otel_collector_environment = [
    { name = "METRICS_ENDPOINT", value = var.metrics_endpoint },
    { name = "OTELCOL_BASE_CONFIG", value = local.otel_base_config },
  ]

  telemetry_token_environment = var.telemetry_token_secret_arn == null ? [
    { name = "TELEMETRY_TOKEN", value = var.telemetry_token == null ? "" : var.telemetry_token },
  ] : []

  telemetry_token_secrets = var.telemetry_token_secret_arn != null ? [
    { name = "TELEMETRY_TOKEN", valueFrom = var.telemetry_token_secret_arn },
  ] : []
}

resource "aws_cloudwatch_log_group" "otel_collector" {
  count = var.telemetry_enabled ? 1 : 0

  name              = "/ecs/otel-collector${local.suffix}"
  retention_in_days = var.otel_log_retention_days

  tags = local.common_tags
}
