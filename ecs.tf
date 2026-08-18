resource "aws_ecs_cluster" "main" {
  name = "app-cluster${local.suffix}"

  setting {
    name  = "containerInsights"
    value = var.ecs_container_insights
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/planar-service${local.suffix}"
  retention_in_days = var.ecs_log_retention_days

  tags = local.common_tags
}

# Container definitions are assembled here rather than inline in the resource so that
# unit tests can assert on their structure during plan. The rendered JSON depends on
# values that are unknown until apply (the ECR URL, the database endpoint), which makes
# the resource attribute itself unusable in a plan-time assertion.
locals {
  task_container_definitions = concat(
    [
      merge(
        {
          name  = "planar-app"
          image = var.repository_name != null ? "${aws_ecr_repository.main[0].repository_url}:latest" : "${var.container_registry_url}/${var.container_image_name}:${var.container_image_tag}"

          portMappings = [
            {
              containerPort = 8000
              hostPort      = 8000
            }
          ]

          logConfiguration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
              "awslogs-region"        = data.aws_region.current.id
              "awslogs-stream-prefix" = "ecs"
            }
          }

          environment = concat(
            [
              {
                name  = "DB_SECRET_NAME"
                value = data.aws_secretsmanager_secret.db_secret.name
              },
              {
                name  = "DB_HOST"
                value = aws_rds_cluster.main.endpoint
              },
              {
                name  = "S3_BUCKET_NAME"
                value = aws_s3_bucket.app_bucket.bucket
              },
              {
                name  = "STAGE"
                value = var.stage
              },
              {
                name  = "APP_NAME"
                value = var.app_name
              },
              {
                name  = "CUSTOM_SECRET_NAME"
                value = aws_secretsmanager_secret.custom_secret.name
              },
              {
                name  = "WORKOS_CLIENT_ID"
                value = var.workos_client_id
              },
              {
                name  = "WORKOS_ORG_ID"
                value = var.workos_org_id
              }
            ],
            [for k, v in var.custom_environment_variables : { name = k, value = v }],
            var.telemetry_enabled ? [
              {
                name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
                value = "http://localhost:4317"
              },
              {
                name  = "OTEL_SERVICE_NAME"
                value = var.app_name
              },
              {
                name  = "OTEL_RESOURCE_ATTRIBUTES"
                value = "deployment.environment=${var.stage},customer.name=${coalesce(var.customer_name, var.app_name)},service.name=${var.app_name}"
              }
            ] : []
          )

          essential = true
        },
        var.container_registry_username != null && var.container_registry_password != null ? {
          repositoryCredentials = {
            credentialsParameter = aws_secretsmanager_secret.registry_credentials[0].arn
          }
        } : {},
        var.app_container_overrides
      )
    ],
    var.telemetry_enabled ? [
      merge(
        {
          name      = "otel-collector"
          image     = "public.ecr.aws/aws-observability/aws-otel-collector:v0.43.2"
          essential = true

          command = ["--config", "env:OTELCOL_BASE_CONFIG"]

          portMappings = [
            { containerPort = 4317, hostPort = 4317 },
            { containerPort = 4318, hostPort = 4318 },
            { containerPort = 13133, hostPort = 13133 },
          ]

          environment = concat(
            local.otel_collector_environment,
            local.telemetry_token_environment,
          )

          healthCheck = {
            command     = ["CMD", "/healthcheck"]
            interval    = 30
            timeout     = 5
            retries     = 3
            startPeriod = 30
          }

          logConfiguration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = aws_cloudwatch_log_group.otel_collector[0].name
              "awslogs-region"        = data.aws_region.current.id
              "awslogs-stream-prefix" = "otel-collector"
            }
          }

        },
        length(local.telemetry_token_secrets) > 0 ? {
          secrets = local.telemetry_token_secrets
        } : {},
      )
    ] : [],
    var.additional_containers,
  )
}

resource "aws_ecs_task_definition" "main" {
  family                   = "planar-service${local.suffix}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode(local.task_container_definitions)

  track_latest = var.ignore_task_definition_changes

  tags = local.common_tags
}

resource "aws_lb" "main" {
  name               = "plb${local.suffix}"
  internal           = var.alb_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.alb_subnets != null ? var.alb_subnets : var.subnets

  enable_deletion_protection = var.stage == "prod" ? true : false

  lifecycle {
    prevent_destroy = true
  }

  dynamic "access_logs" {
    for_each = var.alb_access_logs_enabled ? [1] : []
    content {
      enabled = true
      bucket  = var.alb_access_logs_bucket
      prefix  = var.alb_access_logs_prefix
    }
  }

  tags = local.common_tags
}

resource "aws_lb_target_group" "main" {
  name        = "ptg${local.suffix}"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-499"
    path                = "/planar/v1/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 10
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

locals {
  ecs_service_config = {
    name            = "planar-service${local.suffix}"
    cluster         = aws_ecs_cluster.main.id
    task_definition = aws_ecs_task_definition.main.arn
    desired_count   = var.desired_count
  }
}

resource "aws_ecs_service" "main" {
  count           = var.ignore_task_definition_changes ? 0 : 1
  name            = local.ecs_service_config.name
  cluster         = local.ecs_service_config.cluster
  task_definition = local.ecs_service_config.task_definition
  desired_count   = local.ecs_service_config.desired_count
  launch_type     = "FARGATE"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = var.subnets
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "planar-app"
    container_port   = 8000
  }

  health_check_grace_period_seconds = 60

  depends_on = [
    aws_lb_listener.https,
  ]

  tags = local.common_tags
}

resource "aws_ecs_service" "ignore_task_definition" {
  count           = var.ignore_task_definition_changes ? 1 : 0
  name            = local.ecs_service_config.name
  cluster         = local.ecs_service_config.cluster
  task_definition = local.ecs_service_config.task_definition
  desired_count   = local.ecs_service_config.desired_count
  launch_type     = "FARGATE"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = var.subnets
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "planar-app"
    container_port   = 8000
  }

  health_check_grace_period_seconds = 60

  depends_on = [
    aws_lb_listener.https,
  ]

  tags = local.common_tags

  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.waf_web_acl_arn != null || var.create_waf ? 1 : 0
  resource_arn = aws_lb.main.arn
  web_acl_arn  = var.waf_web_acl_arn != null ? var.waf_web_acl_arn : aws_wafv2_web_acl.main[0].arn
}
