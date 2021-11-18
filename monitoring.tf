
module "nfdiv-fail-alert" {
  source            = "git@github.com:hmcts/cnp-module-metric-alert"
  location          = azurerm_application_insights.appinsights.location
  app_insights_name = azurerm_application_insights.appinsights.name

  alert_name                 = "nfdiv-fail-alert"
  alert_desc                 = "Triggers when an NFDIV exception is received in a 5 minute poll."
  # app_insights_query         = "exceptions | where appName == \"nfdiv-prod\" | sort by timestamp desc"
  app_insights_query         = "exceptions | sort by timestamp desc"
  frequency_in_minutes       = 5
  time_window_in_minutes     = 5
  severity_level             = "3"
  action_group_name          = module.nfdiv-fail-action-group-slack.action_group_name
  custom_email_subject       = "NFDIV Service Exception"
  trigger_threshold_operator = "GreaterThan"
  trigger_threshold          = 0
  resourcegroup_name         = azurerm_resource_group.rg.name
}

module "nfdiv-fail-action-group-slack" {
  source   = "git@github.com:hmcts/cnp-module-action-group"
  location = "global"
  env      = var.env

  resourcegroup_name     = azurerm_resource_group.rg.name
  action_group_name      = "NFDIV Fail Slack Alert - ${var.env}"
  short_name             = "NFDIV_slack"
  email_receiver_name    = "NFDIV Alerts"
  email_receiver_address = "no-fault-divorce-moni-aaaafali3ep7d55ec2d5ddsleq@hmcts-dts.slack.com"
}