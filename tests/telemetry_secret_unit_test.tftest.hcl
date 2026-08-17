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

override_resource {
  target          = aws_iam_role.ecs_execution
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:role/ecs-execution-role-staging-customer-app"
  }
}

override_resource {
  target          = aws_acm_certificate_validation.main
  override_during = plan
  values = {
    certificate_arn = "arn:aws:acm:us-west-2:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }
}

override_resource {
  target          = aws_iam_role.ecs_task
  override_during = plan
  values = {
    arn = "arn:aws:iam::123456789012:role/ecs-task-role-staging-customer-app"
  }
}

variables {
  app_name               = "customer-app"
  base_domain_name       = "example.com"
  container_image_name   = "customer/app"
  container_registry_url = "123456789012.dkr.ecr.us-west-2.amazonaws.com"
  hosted_zone_id         = "Z0123456789ABCDEF"
  stage                  = "staging"
  subnets                = ["subnet-private-a", "subnet-private-b"]
  telemetry_enabled      = true
  vpc_id                 = "vpc-12345678"
  workos_client_id       = "client_test"
  workos_org_id          = "org_test"
}

run "injects_telemetry_token_from_secrets_manager" {
  command = plan

  variables {
    telemetry_token            = "ignored-raw-token"
    telemetry_token_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:telemetry-token"
  }

  assert {
    condition = (
      length(local.telemetry_token_secrets) == 1 &&
      local.telemetry_token_secrets[0].name == "TELEMETRY_TOKEN" &&
      local.telemetry_token_secrets[0].valueFrom == var.telemetry_token_secret_arn
    )
    error_message = "The telemetry token secret must be injected into the collector through ECS secrets."
  }

  assert {
    condition     = alltrue([for item in local.telemetry_token_environment : item.name != "TELEMETRY_TOKEN"])
    error_message = "The raw telemetry token must be omitted when a secret ARN is configured."
  }

  assert {
    condition     = length(aws_iam_role_policy.ecs_execution) == 1
    error_message = "The ECS execution role must receive an inline policy when a telemetry secret is configured."
  }
}

run "preserves_raw_telemetry_token_compatibility" {
  command = plan

  variables {
    telemetry_token            = "legacy-token"
    telemetry_token_secret_arn = null
  }

  assert {
    condition     = length(local.telemetry_token_secrets) == 0
    error_message = "ECS secrets must be omitted when no telemetry secret ARN is configured."
  }

  assert {
    condition     = contains([for item in local.telemetry_token_environment : item.name], "TELEMETRY_TOKEN")
    error_message = "The existing raw telemetry token input must remain supported."
  }
}

run "does_not_grant_secret_access_when_telemetry_is_disabled" {
  command = plan

  variables {
    telemetry_enabled          = false
    telemetry_token_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:unused-telemetry-token"
  }

  assert {
    condition     = length(aws_iam_role_policy.ecs_execution) == 0
    error_message = "The execution role must not receive telemetry secret access when telemetry is disabled."
  }
}

run "exports_deployment_identifiers" {
  command = plan

  assert {
    condition     = output.ecs_execution_role_arn == aws_iam_role.ecs_execution.arn
    error_message = "The ECS execution role ARN output must reference the module execution role."
  }

  assert {
    condition     = output.ecs_task_role_arn == aws_iam_role.ecs_task.arn
    error_message = "The ECS task role ARN output must reference the module task role."
  }

  assert {
    condition     = output.ecs_task_definition_family == aws_ecs_task_definition.main.family
    error_message = "The task definition family output must reference the module task definition."
  }
}
