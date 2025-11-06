// Main deployment template for Azure Advisor Automation
targetScope = 'resourceGroup'

@description('Environment name (e.g., dev, test, prod)')
param environmentName string = 'dev'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Subscription ID to monitor for Advisor recommendations')
param subscriptionId string = subscription().subscriptionId

@description('Tags to apply to all resources')
param resourceTags object = {
  Environment: environmentName
  Project: 'Azure-Advisor-Automation'
  Purpose: 'Automated collection of Azure Advisor recommendations'
}

// Generate unique resource names
var uniqueSuffix = take(uniqueString(resourceGroup().id), 6)
var storageAccountName = 'advisorstorage${uniqueSuffix}'
var logicAppName = 'advisor-automation-${environmentName}-${uniqueSuffix}'
var managedIdentityName = 'advisor-automation-identity-${uniqueSuffix}'

// User-defined types for better parameter organization
type WorkflowParameters = {
  subscriptionId: string
  storageAccountName: string
  containerName: string
}

// Deploy managed identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: resourceTags
}

// Deploy storage account
module storageAccount 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    storageAccountName: storageAccountName
    location: location
    resourceTags: resourceTags
    managedIdentityPrincipalId: managedIdentity.properties.principalId
  }
}

// Deploy Logic App
module logicApp 'modules/logicapp.bicep' = {
  name: 'logicapp-deployment'
  params: {
    logicAppName: logicAppName
    location: location
    resourceTags: resourceTags
    managedIdentityId: managedIdentity.id
    workflowParameters: {
      subscriptionId: subscriptionId
      storageAccountName: storageAccountName
      containerName: 'advisor-recommendations'
    }
  }
  dependsOn: [
    storageAccount
  ]
}

// Role assignments module
module roleAssignments 'modules/roleassignments.bicep' = {
  name: 'role-assignments'
  scope: subscription()
  params: {
    managedIdentityPrincipalId: managedIdentity.properties.principalId
  }
}

// Outputs
@description('Storage account name for Advisor data')
output storageAccountName string = storageAccountName

@description('Logic App name')
output logicAppName string = logicAppName

@description('Managed Identity name')
output managedIdentityName string = managedIdentityName

@description('Storage account resource ID')
output storageAccountId string = storageAccount.outputs.storageAccountId

@description('Logic App resource ID')
output logicAppResourceId string = logicApp.outputs.logicAppId
