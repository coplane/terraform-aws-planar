mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_region" {
    defaults = {
      id   = "us-west-2"
      name = "us-west-2"
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      cidr_block = "10.0.0.0/16"
      id         = "vpc-12345678"
    }
  }

}

mock_provider "null" {}
mock_provider "random" {}

override_resource {
  target          = aws_acm_certificate.main
  override_during = plan
  values = {
    arn = "arn:aws:acm:us-west-2:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    domain_validation_options = [
      {
        domain_name           = "customer-app-staging.example.com"
        resource_record_name  = "_validation.example.com"
        resource_record_type  = "CNAME"
        resource_record_value = "_validation.acm-validations.aws"
      },
    ]
  }
}

variables {
  app_name               = "customer-app"
  stage                  = "staging"
  base_domain_name       = "example.com"
  hosted_zone_id         = "Z0123456789ABCDEF"
  vpc_id                 = "vpc-12345678"
  subnets                = ["subnet-11111111", "subnet-22222222"]
  alb_subnets            = ["subnet-33333333", "subnet-44444444"]
  container_registry_url = "123456789012.dkr.ecr.us-west-2.amazonaws.com"
  container_image_name   = "planar"
  container_image_tag    = "test"
  workos_client_id       = "client_test"
  workos_org_id          = "org_test"

  # Keeps the baseline deterministic: telemetry_enabled defaults to true and would
  # otherwise add the otel-collector container to every assertion below.
  telemetry_enabled = false
}

run "defaults_leave_the_task_definition_unchanged" {
  command = plan

  assert {
    condition     = length(local.task_container_definitions) == 1
    error_message = "With telemetry disabled and no additional containers, only the planar-app container must be defined."
  }

  assert {
    condition     = local.task_container_definitions[0].name == "planar-app"
    error_message = "The first container must remain the application container."
  }

  assert {
    condition     = length(aws_iam_role_policy.ecs_execution) == 0
    error_message = "The execution role policy must not be created when nothing requires it."
  }
}

run "merges_overrides_into_the_app_container" {
  command = plan

  variables {
    app_container_overrides = {
      entryPoint      = ["/opt/sensor/sensor", "daemon", "--"]
      command         = ["/app/planar", "serve"]
      linuxParameters = { capabilities = { add = ["SYS_PTRACE"], drop = [] } }
      secrets = [
        {
          name      = "SENSOR_CLIENT_ID"
          valueFrom = "arn:aws:secretsmanager:us-west-2:123456789012:secret:sensor:SENSOR_CLIENT_ID::"
        },
      ]
      volumesFrom = [{ sourceContainer = "runtime-sensor" }]
      dependsOn   = [{ containerName = "runtime-sensor", condition = "COMPLETE" }]
    }
  }

  assert {
    condition = jsonencode(nonsensitive([
      for c in local.task_container_definitions : c if c.name == "planar-app"
    ][0].entryPoint)) == jsonencode(["/opt/sensor/sensor", "daemon", "--"])
    error_message = "app_container_overrides must replace the app container entryPoint."
  }

  assert {
    condition = jsonencode(nonsensitive([
      for c in local.task_container_definitions : c if c.name == "planar-app"
    ][0].linuxParameters.capabilities.add)) == jsonencode(["SYS_PTRACE"])
    error_message = "app_container_overrides must be able to add Linux capabilities to the app container."
  }

  assert {
    condition = nonsensitive([
      for c in local.task_container_definitions : c if c.name == "planar-app"
    ][0].image) != ""
    error_message = "Overrides must not discard module-managed fields such as the container image."
  }
}

run "appends_additional_containers" {
  command = plan

  variables {
    additional_containers = [
      {
        name      = "runtime-sensor"
        image     = "123456789012.dkr.ecr.us-west-2.amazonaws.com/runtime-sensor:v1"
        essential = false
      },
    ]
  }

  assert {
    condition     = length(local.task_container_definitions) == 2
    error_message = "additional_containers must be appended to the task definition."
  }

  assert {
    condition = contains(
      nonsensitive([for c in local.task_container_definitions : c.name]),
      "runtime-sensor"
    )
    error_message = "The appended sidecar must appear in the task definition by name."
  }
}

run "grants_execution_role_access_to_additional_secrets" {
  command = plan

  variables {
    execution_role_additional_secret_arns = [
      "arn:aws:secretsmanager:us-west-2:123456789012:secret:sensor",
    ]
  }

  assert {
    condition     = length(aws_iam_role_policy.ecs_execution) == 1
    error_message = "The execution role policy must be created when additional secret ARNs are supplied."
  }
}
