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

# CoPlane backend dir-sync token. The value is owned by the caller (read
# cross-account from the backend account) and injected into the app container as
# the COPLANE_API_TOKEN env var via the ECS secrets block.
resource "aws_secretsmanager_secret" "coplane_api_token" {
  count                   = var.coplane_api_token != null ? 1 : 0
  name                    = "coplane-api-token${local.suffix}"
  description             = "CoPlane backend dir-sync service token"
  recovery_window_in_days = var.stage == "prod" ? 30 : 0

  tags = merge(local.common_tags, {
    Name = "coplane-api-token${local.suffix}"
  })
}

resource "aws_secretsmanager_secret_version" "coplane_api_token" {
  count         = var.coplane_api_token != null ? 1 : 0
  secret_id     = aws_secretsmanager_secret.coplane_api_token[0].id
  secret_string = var.coplane_api_token
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