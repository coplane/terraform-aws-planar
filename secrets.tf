resource "aws_secretsmanager_secret" "custom_secret" {
  name                    = "custom-secret${local.suffix}"
  description             = "Custom secret for application configuration"
  recovery_window_in_days = var.stage == "prod" ? 30 : 7

  tags = merge(local.common_tags, {
    Name = "custom-secret${local.suffix}"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "custom_secret" {
  secret_id = aws_secretsmanager_secret.custom_secret.id
  secret_string = jsonencode({
    placeholder_key = "placeholder_value"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "random_password" "otel_monitor" {
  count   = var.otel_database_metrics_enabled ? 1 : 0
  length  = 32
  special = true
  # Avoid characters that complicate postgres connection strings or SQL literals.
  override_special = "!@#%^*()-_=+[]{}<>?"
}

resource "aws_secretsmanager_secret" "otel_monitor" {
  count                   = var.otel_database_metrics_enabled ? 1 : 0
  name                    = "otel-monitor-password${local.suffix}"
  description             = "Password for the OTel postgres monitoring role (otel_monitor)"
  recovery_window_in_days = var.stage == "prod" ? 30 : 7

  tags = merge(local.common_tags, {
    Name = "otel-monitor-password${local.suffix}"
  })
}

resource "aws_secretsmanager_secret_version" "otel_monitor" {
  count         = var.otel_database_metrics_enabled ? 1 : 0
  secret_id     = aws_secretsmanager_secret.otel_monitor[0].id
  secret_string = random_password.otel_monitor[0].result
}

resource "aws_secretsmanager_secret" "registry_credentials" {
  count                   = var.container_registry_username != null && var.container_registry_password != null ? 1 : 0
  name                    = "registry-credentials${local.suffix}"
  description             = "Container registry credentials for ECS image pull"
  recovery_window_in_days = var.stage == "prod" ? 30 : 0

  tags = merge(local.common_tags, {
    Name = "registry-credentials${local.suffix}"
  })
}

resource "aws_secretsmanager_secret_version" "registry_credentials" {
  count     = var.container_registry_username != null && var.container_registry_password != null ? 1 : 0
  secret_id = aws_secretsmanager_secret.registry_credentials[0].id
  secret_string = jsonencode({
    username = var.container_registry_username
    password = var.container_registry_password
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}