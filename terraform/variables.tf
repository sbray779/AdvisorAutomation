# Variables for Azure Advisor Automation Infrastructure

variable "environment" {
  description = "Environment name (e.g., dev, test, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, stage, prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "Central US"
}

variable "resource_tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Development"
    Project     = "Azure-Advisor-Automation"
    Purpose     = "Automated collection of Azure Advisor recommendations"
    Owner       = "DevOps Team"
    CostCenter  = "IT Operations"
  }
}

variable "subscription_id" {
  description = "Azure subscription ID to monitor for Advisor recommendations (optional, defaults to current subscription)"
  type        = string
  default     = null
}

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_replication_type)
    error_message = "Storage replication type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "logic_app_sku" {
  description = "Logic App service plan SKU"
  type        = string
  default     = "WS1"

  validation {
    condition     = contains(["WS1", "WS2", "WS3"], var.logic_app_sku)
    error_message = "Logic App SKU must be one of: WS1, WS2, WS3."
  }
}