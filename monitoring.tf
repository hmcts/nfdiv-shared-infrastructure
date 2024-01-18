
data "azurerm_key_vault_secret" "slack_monitoring_address" {
  name         = "slack-monitoring-address"
  key_vault_id = "${module.key-vault.key_vault_id}"
}

output "slack_monitoring_address" {
  value = data.azurerm_key_vault_secret.slack_monitoring_address
}

module "nfdiv-fail-alert" {
  source            = "git@github.com:hmcts/cnp-module-metric-alert"
  location          = var.appinsights_location
  app_insights_name = module.application_insights.name

  alert_name                 = "nfdiv-fail-alert"
  alert_desc                 = "Triggers when an NFDIV exception is received in a 5 minute poll."
  app_insights_query         = "requests | where toint(resultCode) >= 400 | sort by timestamp desc"
  frequency_in_minutes       = 15
  time_window_in_minutes     = 15
  severity_level             = "3"
  action_group_name          = module.nfdiv-fail-action-group-slack.action_group_name
  custom_email_subject       = "NFDIV Service Exception"
  trigger_threshold_operator = "GreaterThan"
  trigger_threshold          = 0
  resourcegroup_name         = azurerm_resource_group.rg.name
  common_tags                = var.common_tags
}

module "nfdiv-migration-alert" {
  source            = "git@github.com:hmcts/cnp-module-metric-alert"
  location          = var.appinsights_location
  app_insights_name = module.application_insights.name

  alert_name                 = "nfdiv-migration-alert"
  alert_desc                 = "Triggers when a migration fails."
  app_insights_query         = "traces | where message contains \"Setting dataVersion to 0 for case id\" | sort by timestamp desc"
  frequency_in_minutes       = 60
  time_window_in_minutes     = 60
  severity_level             = "1"
  action_group_name          = module.nfdiv-fail-action-group-slack.action_group_name
  custom_email_subject       = "NFDIV Migration Failed"
  trigger_threshold_operator = "GreaterThan"
  trigger_threshold          = 0
  resourcegroup_name         = azurerm_resource_group.rg.name
  common_tags                = var.common_tags
}

module "nfdiv-fail-action-group-slack" {
  source   = "git@github.com:hmcts/cnp-module-action-group"
  location = "global"
  env      = var.env

  resourcegroup_name     = azurerm_resource_group.rg.name
  action_group_name      = "NFDIV Fail Slack Alert - ${var.env}"
  short_name             = "NFDIV_slack"
  email_receiver_name    = "NFDIV Alerts"
  email_receiver_address = "${data.azurerm_key_vault_secret.slack_monitoring_address.value}"
}
