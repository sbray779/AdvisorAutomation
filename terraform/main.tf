# Azure Advisor Automation Infrastructure
# Terraform configuration for automated collection of Azure Advisor recommendations

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Data sources
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# Resource Group
resource "azurerm_resource_group" "advisor_automation" {
  name     = "rg-advisor-automation-${var.environment}-${random_string.suffix.result}"
  location = var.location
  tags     = var.resource_tags
}

# User-assigned Managed Identity
resource "azurerm_user_assigned_identity" "advisor_automation" {
  name                = "id-advisor-automation-${var.environment}-${random_string.suffix.result}"
  location            = azurerm_resource_group.advisor_automation.location
  resource_group_name = azurerm_resource_group.advisor_automation.name
  tags                = var.resource_tags
}

# Storage Account for CSV output
resource "azurerm_storage_account" "advisor_data" {
  name                     = "advisorstorage${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.advisor_automation.name
  location                 = azurerm_resource_group.advisor_automation.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  https_traffic_only_enabled      = true

  blob_properties {
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }

  tags = var.resource_tags
}

# Storage Container for Advisor recommendations
resource "azurerm_storage_container" "advisor_recommendations" {
  name               = "advisor-recommendations"
  storage_account_id = azurerm_storage_account.advisor_data.id

  metadata = {
    purpose = "Azure Advisor recommendations CSV storage"
  }
}

# Storage Account for Logic App runtime
resource "azurerm_storage_account" "logic_app_runtime" {
  name                     = "logicapp${random_string.suffix.result}storage"
  resource_group_name      = azurerm_resource_group.advisor_automation.name
  location                 = azurerm_resource_group.advisor_automation.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  https_traffic_only_enabled      = true

  tags = var.resource_tags
}

# App Service Plan for Logic App
resource "azurerm_service_plan" "logic_app" {
  name                = "plan-advisor-automation-${var.environment}-${random_string.suffix.result}"
  location            = azurerm_resource_group.advisor_automation.location
  resource_group_name = azurerm_resource_group.advisor_automation.name
  os_type             = "Windows"
  sku_name            = "WS1"
  tags                = var.resource_tags
}

# Logic App (Standard)
resource "azurerm_logic_app_standard" "advisor_automation" {
  name                       = "logic-advisor-automation-${var.environment}-${random_string.suffix.result}"
  location                   = azurerm_resource_group.advisor_automation.location
  resource_group_name        = azurerm_resource_group.advisor_automation.name
  app_service_plan_id        = azurerm_service_plan.logic_app.id
  storage_account_name       = azurerm_storage_account.logic_app_runtime.name
  storage_account_access_key = azurerm_storage_account.logic_app_runtime.primary_access_key
  version                    = "~4"

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.advisor_automation.id
    ]
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"                            = "node"
    "WEBSITE_NODE_DEFAULT_VERSION"                        = "~18"
    "AzureFunctionsJobHost__extensionBundle__id"          = "Microsoft.Azure.Functions.ExtensionBundle.Workflows"
    "AzureFunctionsJobHost__extensionBundle__version"     = "[1.*, 2.0.0)"
    "WORKFLOWS_SUBSCRIPTION_ID"                           = data.azurerm_subscription.current.subscription_id
    "WORKFLOWS_STORAGE_ACCOUNT_NAME"                      = azurerm_storage_account.advisor_data.name
    "WORKFLOWS_CONTAINER_NAME"                            = azurerm_storage_container.advisor_recommendations.name
  }

  site_config {
    dotnet_framework_version         = "v6.0"
    use_32_bit_worker_process        = false
    ftps_state                       = "FtpsOnly"
    min_tls_version                  = "1.2"
    scm_min_tls_version             = "1.2"
    http2_enabled                    = true
    always_on                        = false
    auto_swap_slot_name             = ""
    health_check_path               = ""
  }

  tags = var.resource_tags
}

# Role Assignment: Reader role for subscription (Azure Advisor API access)
resource "azurerm_role_assignment" "advisor_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.advisor_automation.principal_id
  description          = "Allows the Logic App to read Azure Advisor recommendations at subscription level"
}

# Role Assignment: Storage Blob Data Contributor for storage account
resource "azurerm_role_assignment" "storage_contributor" {
  scope                = azurerm_storage_account.advisor_data.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.advisor_automation.principal_id
  description          = "Allows the Logic App managed identity to upload CSV files to storage"
}