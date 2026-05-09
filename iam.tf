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
    for_each = var.otel_database_metrics_enabled ? [1] : []
    content {
      sid = "OtelMonitorPasswordAccess"
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      resources = [aws_secretsmanager_secret.otel_monitor[0].arn]
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

}

resource "aws_iam_role_policy" "ecs_execution" {
  count = (
    var.repository_name != null ||
    (var.container_registry_username != null && var.container_registry_password != null) ||
    var.otel_database_metrics_enabled
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
    resources = concat(
      [
        aws_rds_cluster.main.master_user_secret[0].secret_arn,
        aws_secretsmanager_secret.custom_secret.arn,
      ],
      var.otel_database_metrics_enabled ? [aws_secretsmanager_secret.otel_monitor[0].arn] : [],
    )
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