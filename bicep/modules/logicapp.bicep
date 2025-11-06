// Logic App module for Azure Advisor Automation
@description('Logic App name')
param logicAppName string

@description('Azure region')
param location string

@description('Resource tags')
param resourceTags object

@description('Managed Identity resource ID')
param managedIdentityId string

@description('Workflow parameters')
param workflowParameters object

// App Service Plan for Logic App
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${logicAppName}-plan'
  location: location
  tags: resourceTags
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
  }
  kind: 'elastic'
  properties: {
    maximumElasticWorkerCount: 20
    targetWorkerCount: 1
    targetWorkerSizeId: 0
  }
}

// Storage account for Logic App runtime
resource logicAppStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: take('${replace(logicAppName, '-', '')}storage', 24)
  location: location
  tags: resourceTags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// Logic App (Standard)
resource logicApp 'Microsoft.Web/sites@2023-12-01' = {
  name: logicAppName
  location: location
  tags: resourceTags
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      netFrameworkVersion: 'v6.0'
      functionsRuntimeScaleMonitoringEnabled: false
      appSettings: [
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${logicAppStorage.name};AccountKey=${logicAppStorage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
        }
        {
          name: 'WORKFLOWS_SUBSCRIPTION_ID'
          value: workflowParameters.subscriptionId
        }
        {
          name: 'WORKFLOWS_STORAGE_ACCOUNT_NAME'
          value: workflowParameters.storageAccountName
        }
        {
          name: 'WORKFLOWS_CONTAINER_NAME'
          value: workflowParameters.containerName
        }
      ]
    }
  }
}

// Outputs
@description('Logic App resource ID')
output logicAppId string = logicApp.id

@description('Logic App name')
output logicAppName string = logicApp.name

@description('Logic App default hostname')
output defaultHostName string = logicApp.properties.defaultHostName

@description('Logic App storage account name')
output logicAppStorageName string = logicAppStorage.name
