using 'main.bicep'

// Environment configuration
param environmentName = 'dev'
param location = 'East US 2'

// Subscription to monitor (defaults to current subscription)
param subscriptionId = '' // Will use current subscription if empty

// Resource tags
param resourceTags = {
  Environment: 'Development'
  Project: 'Azure-Advisor-Automation'
  Purpose: 'Automated collection of Azure Advisor recommendations'
  Owner: 'DevOps Team'
  CostCenter: 'IT Operations'
}
