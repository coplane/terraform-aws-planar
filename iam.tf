data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "ecs-execution-role${local.suffix}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_execution_policy" {
  dynamic "statement" {
    for_each = var.container_registry_username != null && var.container_registry_password != null ? [1] : []
    content {
      sid = "RegistryCredentialsAccess"
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      resources = [
        aws_secretsmanager_secret.registry_credentials[0].arn
      ]
    }
  }

  dynamic "statement" {
    for_each = var.repository_name != null ? [1] : []
    content {
      sid = "ECRGetAuthorizationToken"
      actions = [
        "ecr:GetAuthorizationToken"
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = var.repository_name != null ? [1] : []
    content {
      sid = "ECRRepositoryAccess"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:DescribeRepositories"
      ]
      resources = [
        aws_ecr_repository.main[0].arn
      ]
    }
  }

  dynamic "statement" {
    for_each = var.telemetry_enabled && var.telemetry_token_secret_arn != null ? [1] : []
    content {
      sid = "TelemetryTokenAccess"
      actions = [
        "secretsmanager:GetSecretValue",
      ]
      resources = [var.telemetry_token_secret_arn]
    }
  }

  dynamic "statement" {
    for_each = length(var.execution_role_additional_secret_arns) > 0 ? [1] : []
    content {
      sid = "AdditionalSecretsAccess"
      actions = [
        "secretsmanager:GetSecretValue",
      ]
      resources = var.execution_role_additional_secret_arns
    }
  }

  # Secrets encrypted with a customer-managed KMS key additionally require kms:Decrypt
  # on that key. Secrets using the AWS-managed aws/secretsmanager key do not, which is
  # why this is opt-in rather than derived from the secret ARNs above.
  dynamic "statement" {
    for_each = length(var.execution_role_additional_kms_key_arns) > 0 ? [1] : []
    content {
      sid = "AdditionalSecretsKmsDecrypt"
      actions = [
        "kms:Decrypt",
      ]
      resources = var.execution_role_additional_kms_key_arns
    }
  }

}

resource "aws_iam_role_policy" "ecs_execution" {
  count = (
    var.repository_name != null ||
    (var.container_registry_username != null && var.container_registry_password != null) ||
    (var.telemetry_enabled && var.telemetry_token_secret_arn != null) ||
    length(var.execution_role_additional_secret_arns) > 0 ||
    length(var.execution_role_additional_kms_key_arns) > 0
  ) ? 1 : 0
  name   = "ecs-execution-policy${local.suffix}"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.ecs_execution_policy.json
}

resource "aws_iam_role" "ecs_task" {
  name               = "ecs-task-role${local.suffix}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "ecs_task_policy" {
  statement {
    sid = "SecretsManagerAccess"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      aws_rds_cluster.main.master_user_secret[0].secret_arn,
      aws_secretsmanager_secret.custom_secret.arn
    ]
  }

  statement {
    sid = "S3Access"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = [
      aws_s3_bucket.app_bucket.arn,
      "${aws_s3_bucket.app_bucket.arn}/*"
    ]
  }

  statement {
    sid = "S3ListBucket"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.app_bucket.arn
    ]
  }

  statement {
    sid = "BedrockAccess"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:ListFoundationModels",
      "bedrock:GetFoundationModel"
    ]
    resources = ["*"]
  }

}

resource "aws_iam_role_policy" "ecs_task" {
  name   = "ecs-task-policy${local.suffix}"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_policy.json
}

#Inline policy for Bedrock Mantle, used e.g for GPT-5.6 Luna model.
resource "aws_iam_role_policy_attachment" "ecs_task_bedrock_mantle" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockMantleInferenceAccess"
}
