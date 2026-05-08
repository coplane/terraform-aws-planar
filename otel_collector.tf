locals {
  otel_base_config = var.telemetry_enabled ? templatefile("${path.module}/templates/otel_collector.yaml.tftpl", {
    enable_ecs_container_metrics = var.enable_ecs_container_metrics
    enable_logs_pipeline         = var.enable_logs_pipeline
    enable_database_metrics      = var.otel_database_metrics_enabled
    metrics_endpoint             = "$${env:METRICS_ENDPOINT}"
    telemetry_token              = "$${env:TELEMETRY_TOKEN}"
    service_name                 = var.app_name
    customer_name                = coalesce(var.customer_name, var.app_name)
    stage                        = var.stage
    rds_endpoint                 = aws_rds_cluster.main.endpoint
    otel_db_user                 = "otel_monitor"
  }) : null
}

resource "aws_cloudwatch_log_group" "otel_collector" {
  count = var.telemetry_enabled ? 1 : 0

  name              = "/ecs/otel-collector${local.suffix}"
  retention_in_days = var.otel_log_retention_days

  tags = local.common_tags
}
