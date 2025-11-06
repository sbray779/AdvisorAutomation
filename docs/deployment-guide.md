# Deployment Guide

This guide provides detailed instructions for deploying the Azure Advisor Automation solution.

## Prerequisites

### Azure Permissions Required

- **Subscription Level**:
  - Reader (to access Advisor recommendations)
  - User Access Administrator (to assign roles)

- **Resource Group Level**:
  - Contributor (to create and manage resources)

### Tools Required

Choose one deployment method:

#### For Bicep Deployment
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) version 2.37.0+
- [Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) (usually included with Azure CLI)

#### For Terraform Deployment
- [Terraform](https://www.terraform.io/downloads) version 1.5.0+
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (for authentication)

## Bicep Deployment

### Step 1: Prepare Environment

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "your-subscription-id"

# Create resource group
az group create \
  --name "rg-advisor-automation-prod" \
  --location "East US 2"

# Verify resource group
az group show --name "rg-advisor-automation-prod"
```

### Step 2: Configure Parameters

Edit `bicep/main.bicepparam`:

```bicep
using 'main.bicep'

param environmentName = 'prod'
param location = 'East US 2'
param subscriptionId = 'your-subscription-id'

param resourceTags = {
  Environment: 'Production'
  Project: 'Azure-Advisor-Automation'
  Owner: 'Platform Team'
  CostCenter: 'IT-Operations'
}
```

### Step 3: Deploy Infrastructure

```bash
cd bicep

# Validate template
az deployment group validate \
  --resource-group "rg-advisor-automation-prod" \
  --template-file main.bicep \
  --parameters main.bicepparam

# Deploy infrastructure
az deployment group create \
  --resource-group "rg-advisor-automation-prod" \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --mode Incremental
```

### Step 4: Verify Deployment

```bash
# Check deployment status
az deployment group list \
  --resource-group "rg-advisor-automation-prod" \
  --query "[?properties.provisioningState=='Succeeded']"

# List deployed resources
az resource list \
  --resource-group "rg-advisor-automation-prod" \
  --output table
```

## Terraform Deployment

### Step 1: Prepare Environment

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "your-subscription-id"

# Clone repository
git clone <repository-url>
cd AdvisorAutomation/terraform
```

### Step 2: Configure Variables

```bash
# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
vim terraform.tfvars
```

Example `terraform.tfvars`:

```hcl
environment = "prod"
location    = "East US 2"

resource_tags = {
  Environment = "Production"
  Project     = "Azure-Advisor-Automation"
  Owner       = "Platform Team"
  CostCenter  = "IT-Operations"
}

storage_replication_type = "GRS"  # For production
logic_app_sku           = "WS2"  # For higher throughput
```

### Step 3: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan
```

### Step 4: Verify Deployment

```bash
# Show outputs
terraform output

# Verify resources in Azure
az resource list \
  --resource-group $(terraform output -raw resource_group_name) \
  --output table
```

## Post-Deployment Configuration

### Configure Logic App Workflow

1. **Navigate to Logic App** in Azure Portal
2. **Upload Workflow Definition**:
   - Go to Workflows → Import
   - Upload `logic-app/workflow-simple.json`
   - Configure parameters

3. **Test Workflow**:
   - Trigger manually to verify functionality
   - Check run history for errors

### Set Up Monitoring

1. **Enable Application Insights**:
   ```bash
   # Create Application Insights
   az monitor app-insights component create \
     --app advisor-automation-insights \
     --location "East US 2" \
     --resource-group "rg-advisor-automation-prod"
   
   # Link to Logic App
   az logicapp config appsettings set \
     --name "your-logic-app-name" \
     --resource-group "rg-advisor-automation-prod" \
     --settings APPINSIGHTS_INSTRUMENTATIONKEY="your-instrumentation-key"
   ```

2. **Create Alerts**:
   ```bash
   # Alert on Logic App failures
   az monitor metrics alert create \
     --name "LogicApp-Failures" \
     --resource-group "rg-advisor-automation-prod" \
     --scopes "/subscriptions/your-sub/resourceGroups/rg-advisor-automation-prod/providers/Microsoft.Web/sites/your-logic-app" \
     --condition "count 'RunsSucceeded' < 1" \
     --description "Logic App failed to run successfully"
   ```

## Environment-Specific Configurations

### Development Environment

```bash
# Bicep
az deployment group create \
  --resource-group "rg-advisor-automation-dev" \
  --template-file main.bicep \
  --parameters environmentName=dev location="East US 2"

# Terraform
terraform workspace new dev
terraform apply -var="environment=dev"
```

### Production Environment

```bash
# Bicep
az deployment group create \
  --resource-group "rg-advisor-automation-prod" \
  --template-file main.bicep \
  --parameters environmentName=prod location="East US 2"

# Terraform
terraform workspace new prod
terraform apply -var="environment=prod" -var="storage_replication_type=GRS"
```

## Troubleshooting Deployment Issues

### Common Bicep Issues

1. **Resource name conflicts**:
   ```bash
   # Check existing resources
   az resource list --name "*advisor*" --output table
   ```

2. **Permission errors**:
   ```bash
   # Verify role assignments
   az role assignment list --assignee $(az account show --query user.name -o tsv)
   ```

### Common Terraform Issues

1. **State file conflicts**:
   ```bash
   # Initialize with backend
   terraform init -reconfigure
   ```

2. **Provider version issues**:
   ```bash
   # Upgrade providers
   terraform init -upgrade
   ```

## Cleanup

### Remove Resources

#### Bicep
```bash
az group delete --name "rg-advisor-automation-dev" --yes --no-wait
```

#### Terraform
```bash
terraform destroy -auto-approve
```

## Next Steps

After successful deployment:

1. **Verify Data Collection**: Check storage account for CSV files after first run
2. **Set Up Reporting**: Create Power BI dashboard or Azure Workbook
3. **Implement Governance**: Set up cost alerts and resource policies
4. **Documentation**: Update runbooks and operational procedures