locals {
  default_waf_rules = [
    {
      name    = "aws-common-rules"
      managed = "AWSManagedRulesCommonRuleSet"
      metric  = "waf-common-rules"
      vendor  = "AWS"
    },
    {
      name    = "aws-known-bad-inputs"
      managed = "AWSManagedRulesKnownBadInputsRuleSet"
      metric  = "waf-known-bad-inputs"
      vendor  = "AWS"
    },
    {
      name    = "aws-sqli"
      managed = "AWSManagedRulesSQLiRuleSet"
      metric  = "waf-sqli"
      vendor  = "AWS"
    },
  ]

  extra_waf_rules = [
    for rule in var.waf_managed_rule_groups : {
      name    = rule.name
      managed = rule.name
      metric  = rule.metric
      vendor  = rule.vendor
    }
  ]

  all_waf_rules = concat(local.default_waf_rules, local.extra_waf_rules)
}

resource "aws_wafv2_web_acl" "main" {
  count = var.create_waf ? 1 : 0

  name  = "waf${local.suffix}"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = { for idx, rule in local.all_waf_rules : idx => rule }

    content {
      name     = rule.value.name
      priority = rule.key + 1

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.managed
          vendor_name = rule.value.vendor

          dynamic "rule_action_override" {
            for_each = rule.value.managed == "AWSManagedRulesCommonRuleSet" ? [
              "SizeRestrictions_BODY",
              "CrossSiteScripting_BODY",
              "GenericRFI_BODY",
            ] : []
            content {
              name = rule_action_override.value
              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${rule.value.metric}${local.suffix}"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf${local.suffix}"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}
