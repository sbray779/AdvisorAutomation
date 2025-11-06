// Role assignments module for Azure Advisor Automation
targetScope = 'subscription'

@description('Managed Identity Principal ID')
param managedIdentityPrincipalId string

// Reader role assignment at subscription level for Azure Advisor API access
resource advisorReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, managedIdentityPrincipalId, 'Reader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Allows the Logic App to read Azure Advisor recommendations at subscription level'
  }
}

// Outputs
@description('Advisor Reader role assignment ID')
output advisorReaderRoleAssignmentId string = advisorReaderRole.id
