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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
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
  name                 = "advisor-recommendations"
  storage_account_name = azurerm_storage_account.advisor_data.name

  metadata = {
    purpose = "Azure Advisor recommendations CSV storage"
  }
}

# Consumption-based Logic Apps don't require an App Service Plan or runtime storage
# resource "azurerm_service_plan" "logic_app" {
#   name                = "plan-advisor-automation-${var.environment}-${random_string.suffix.result}"
#   location            = azurerm_resource_group.advisor_automation.location
#   resource_group_name = azurerm_resource_group.advisor_automation.name
#   os_type             = "Windows"
#   sku_name            = "WS1"
#   tags                = var.resource_tags
# }

# Logic App Workflow Definition
locals {
  workflow_definition = templatefile("${path.module}/workflow-definition.json.tpl", {
    subscription_id      = data.azurerm_subscription.current.subscription_id
    storage_account_name = azurerm_storage_account.advisor_data.name
    container_name       = azurerm_storage_container.advisor_recommendations.name
    managed_identity_id  = azurerm_user_assigned_identity.advisor_automation.id
  })
}

# Logic App (Consumption-based for better reliability)
resource "azurerm_logic_app_workflow" "advisor_automation" {
  name                = "logic-advisor-automation-${var.environment}-${random_string.suffix.result}"
  location            = azurerm_resource_group.advisor_automation.location
  resource_group_name = azurerm_resource_group.advisor_automation.name

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.advisor_automation.id
    ]
  }

  tags = var.resource_tags

  # Wait for role assignments to propagate
  depends_on = [
    azurerm_role_assignment.advisor_reader,
    azurerm_role_assignment.storage_contributor
  ]
}

# Deploy workflow definition using Azure REST API
resource "local_file" "workflow_definition_file" {
  content  = local.workflow_definition
  filename = "${path.module}/workflow-definition-temp.json"
}

resource "null_resource" "deploy_workflow_definition" {
  triggers = {
    workflow_definition = local.workflow_definition
    logic_app_id        = azurerm_logic_app_workflow.advisor_automation.id
    always_run          = timestamp()
  }

  provisioner "local-exec" {
    command     = "pwsh -File deploy-workflow.ps1 -WorkflowJsonFile \"${abspath(local_file.workflow_definition_file.filename)}\" -LogicAppId \"${azurerm_logic_app_workflow.advisor_automation.id}\" -Location \"${azurerm_logic_app_workflow.advisor_automation.location}\" -ManagedIdentityId \"${azurerm_user_assigned_identity.advisor_automation.id}\" -TagsJson '${replace(jsonencode(var.resource_tags), "'", "''")}'"
    working_dir = path.module
    interpreter = ["pwsh", "-Command"]
  }

  depends_on = [
    azurerm_logic_app_workflow.advisor_automation,
    azurerm_role_assignment.advisor_reader,
    azurerm_role_assignment.storage_contributor,
    local_file.workflow_definition_file
  ]
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