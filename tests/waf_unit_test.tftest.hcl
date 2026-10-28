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
  telemetry_enabled      = false
  create_waf             = true
}

run "no_user_agent_is_counted_by_the_common_rule_set" {
  command = plan

  assert {
    condition = contains(flatten([
      for rule in aws_wafv2_web_acl.main[0].rule : [
        for override in rule.statement[0].managed_rule_group_statement[0].rule_action_override : override.name
      ] if rule.name == "aws-common-rules"
    ]), "NoUserAgent_HEADER")
    error_message = "NoUserAgent_HEADER must be overridden to count so MCP paths can be exempted."
  }
}

run "no_user_agent_is_blocked_outside_mcp_paths" {
  command = plan

  assert {
    condition = one([
      for rule in aws_wafv2_web_acl.main[0].rule : rule.priority if rule.name == "block-no-user-agent"
    ]) == length(local.all_waf_rules) + 1
    error_message = "block-no-user-agent must run after every managed rule group so the NoUserAgent label exists."
  }

  assert {
    condition = one([
      for rule in aws_wafv2_web_acl.main[0].rule :
      rule.statement[0].and_statement[0].statement[0].label_match_statement[0].key if rule.name == "block-no-user-agent"
    ]) == "awswaf:managed:aws:core-rule-set:NoUserAgent_Header"
    error_message = "block-no-user-agent must match the CommonRuleSet NoUserAgent label."
  }

  assert {
    condition = one([
      for rule in aws_wafv2_web_acl.main[0].rule :
      rule.statement[0].and_statement[0].statement[1].not_statement[0].statement[0].regex_match_statement[0].regex_string if rule.name == "block-no-user-agent"
    ]) == local.mcp_path_regex
    error_message = "block-no-user-agent must exempt only the MCP paths."
  }
}

run "bot_control_and_no_user_agent_share_the_mcp_exemption" {
  command = plan

  variables {
    waf_managed_rule_groups = [{
      name   = "AWSManagedRulesBotControlRuleSet"
      metric = "waf-bot-control"
    }]
  }

  assert {
    condition = one([
      for rule in aws_wafv2_web_acl.main[0].rule :
      rule.statement[0].managed_rule_group_statement[0].scope_down_statement[0].not_statement[0].statement[0].regex_match_statement[0].regex_string
      if rule.name == "AWSManagedRulesBotControlRuleSet"
    ]) == local.mcp_path_regex
    error_message = "Bot Control must exempt the same MCP paths."
  }

  assert {
    condition = one([
      for rule in aws_wafv2_web_acl.main[0].rule : rule.priority if rule.name == "block-no-user-agent"
    ]) == 5
    error_message = "block-no-user-agent must stay after extra managed rule groups."
  }
}
