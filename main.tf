provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.product}-${var.env}"
  location = var.location

  tags = var.common_tags
}

module "key-vault" {
  source              = "git@github.com:hmcts/cnp-module-key-vault?ref=master"
  product             = var.product
  env                 = var.env
  tenant_id           = var.tenant_id
  object_id           = var.jenkins_AAD_objectId
  resource_group_name = azurerm_resource_group.rg.name

  # dcd_platformengineering group object ID
  product_group_name      = "dcd_divorce"
  common_tags             = var.common_tags
  create_managed_identity = true
}

resource "azurerm_key_vault_secret" "AZURE_APPINSIGHTS_KEY" {
  name         = "AppInsightsInstrumentationKey"
  value        = module.application_insights.instrumentation_key
  key_vault_id = module.key-vault.key_vault_id
}

module "application_insights" {
  source = "git@github.com:hmcts/terraform-module-application-insights?ref=main"

  env                 = var.env
  product             = var.product
  location            = var.appinsights_location
  resource_group_name = azurerm_resource_group.rg.name
  common_tags         = var.common_tags
  name                = "${var.product}-appinsights"
}

moved {
  from = azurerm_application_insights.appinsights
  to   = module.application_insights.azurerm_application_insights.this
}

resource "azurerm_key_vault_secret" "AZURE_APPINSIGHTS_KEY_PREVIEW" {
  name         = "AppInsightsInstrumentationKey-Preview"
  value        = module.application_insights_preview.instrumentation_key
  key_vault_id = module.key-vault.key_vault_id
  count        = var.env == "aat" ? 1 : 0
}

data "azurerm_key_vault" "s2s_vault" {
  name                = "s2s-${var.env}"
  resource_group_name = "rpe-service-auth-provider-${var.env}"
}

data "azurerm_key_vault_secret" "nfdiv_case_api_s2s_key" {
  name         = "microservicekey-nfdiv-case-api"
  key_vault_id = data.azurerm_key_vault.s2s_vault.id
}

resource "azurerm_key_vault_secret" "nfdiv_case_api_s2s_secret" {
  name         = "s2s-case-api-secret"
  value        = data.azurerm_key_vault_secret.nfdiv_case_api_s2s_key.value
  key_vault_id = module.key-vault.key_vault_id
}

data "azurerm_key_vault_secret" "nfdiv_frontend_s2s_key" {
  name         = "microservicekey-divorce-frontend"
  key_vault_id = data.azurerm_key_vault.s2s_vault.id
}

resource "azurerm_key_vault_secret" "nfdiv_frontend_s2s_secret" {
  name         = "frontend-secret"
  value        = data.azurerm_key_vault_secret.nfdiv_frontend_s2s_key.value
  key_vault_id = module.key-vault.key_vault_id
}

locals {
  application_insights_enabled = var.env == "aat"
}
module "application_insights_preview" {
  source = "git@github.com:hmcts/terraform-module-application-insights?ref=main"

  env                 = var.env
  product             = var.product
  location            = var.appinsights_location
  resource_group_name = local.application_insights_enabled ? azurerm_resource_group.rg.name : null
  common_tags         = var.common_tags
  override_name       = "${var.product}-appinsights-preview"
}

moved {
  from = module.application_insights_preview[0].azurerm_application_insights.this
  to   = module.application_insights_preview.azurerm_application_insights.this
}

/*
data "azurerm_key_vault_secret" "alerts_email" {
  name      = "alerts-email"
  key_vault_id = module.key-vault.key_vault_id
}
*/

resource "azurerm_monitor_action_group" "appinsights" {
  name                = "nfdiv-ag1"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "nfdiv-alerts"

  email_receiver {
    name = "sendtoadmin"
    //    email_address = data.azurerm_key_vault_secret.alerts_email.value
    email_address = "div-support2@HMCTS.NET"

  }

  webhook_receiver {
    name                    = "nfdiv-l-app"
    service_uri             = "https://prod-00.uksouth.logic.azure.com:443/workflows/92968083557f446bb6acff64ea3afa69/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=FWSXTSNydGuxnZy9q_34_QDp1IIsZeP8yRdpCmLOKc8"
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_metric_alert" "metric_alert_exceptions" {
  name                = "exceptions_alert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [module.application_insights.id]
  description         = "Alert will be triggered when Exceptions are more than 2 per 5 mins"

  criteria {
    metric_namespace = "Microsoft.Insights/Components"
    metric_name      = "performanceCounters/exceptionsPerSecond"
    aggregation      = "Maximum"
    operator         = "GreaterThanOrEqual"
    threshold        = 2

  }

  action {
    action_group_id = azurerm_monitor_action_group.appinsights.id
  }
  count = var.custom_alerts_enabled ? 1 : 0
}
