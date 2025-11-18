# Outputs for Azure Advisor Automation Infrastructure

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.advisor_automation.name
}

output "resource_group_id" {
  description = "Resource group ID"
  value       = azurerm_resource_group.advisor_automation.id
}

output "storage_account_name" {
  description = "Name of the storage account for Advisor data"
  value       = azurerm_storage_account.advisor_data.name
}

output "storage_account_id" {
  description = "Storage account resource ID"
  value       = azurerm_storage_account.advisor_data.id
}

output "storage_container_name" {
  description = "Name of the storage container for Advisor recommendations"
  value       = azurerm_storage_container.advisor_recommendations.name
}

output "logic_app_name" {
  description = "Name of the Logic App"
  value       = azurerm_logic_app_workflow.advisor_automation.name
}

output "logic_app_id" {
  description = "Logic App resource ID"
  value       = azurerm_logic_app_workflow.advisor_automation.id
}

output "managed_identity_name" {
  description = "Name of the managed identity"
  value       = azurerm_user_assigned_identity.advisor_automation.name
}

output "managed_identity_id" {
  description = "Managed identity resource ID"
  value       = azurerm_user_assigned_identity.advisor_automation.id
}

output "managed_identity_principal_id" {
  description = "Managed identity principal ID"
  value       = azurerm_user_assigned_identity.advisor_automation.principal_id
  sensitive   = true
}

output "managed_identity_client_id" {
  description = "Managed identity client ID"
  value       = azurerm_user_assigned_identity.advisor_automation.client_id
  sensitive   = true
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    resource_group    = azurerm_resource_group.advisor_automation.name
    storage_account   = azurerm_storage_account.advisor_data.name
    logic_app         = azurerm_logic_app_workflow.advisor_automation.name
    managed_identity  = azurerm_user_assigned_identity.advisor_automation.name
    container_name    = azurerm_storage_container.advisor_recommendations.name
    location          = var.location
    environment       = var.environment
  }
}

output "logic_app_trigger_url" {
  description = "Logic App callback URL for manual trigger (use az rest to retrieve)"
  value       = "Run: az rest --method POST --uri 'https://management.azure.com${azurerm_logic_app_workflow.advisor_automation.id}/triggers/DailySchedule/run?api-version=2016-06-01'"
}

output "view_logic_app_portal" {
  description = "Azure Portal URL for Logic App"
  value       = "https://portal.azure.com/#@/resource${azurerm_logic_app_workflow.advisor_automation.id}"
}