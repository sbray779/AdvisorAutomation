# Terraform Deployment for Azure Advisor Automation

This Terraform configuration deploys a complete Azure Advisor automation solution including the Logic App workflow definition.

## What Gets Deployed

### Infrastructure
- **Resource Group**: Container for all resources
- **Storage Account**: For storing JSON reports
- **Storage Container**: `advisor-recommendations` container
- **Managed Identity**: User-assigned identity for secure authentication
- **Logic App**: Consumption-based Logic App with workflow definition
- **RBAC Assignments**: Reader (subscription) and Storage Blob Data Contributor roles

### Logic App Workflow
The Terraform configuration automatically deploys a complete workflow that:
- Runs daily at 6:00 AM UTC
- Queries Azure Advisor API for all recommendations with automatic pagination
- Collects all recommendations across multiple pages using $skiptoken
- Uploads complete raw JSON data to storage with timestamp

## Prerequisites

1. **Azure CLI**: Installed and authenticated (`az login`)
2. **Terraform**: Version 1.5 or later
3. **PowerShell**: For workflow deployment provisioner

## Deployment Steps

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

### 3. Deploy Infrastructure and Workflow

```bash
terraform apply
```

The deployment will:
1. Create all Azure resources
2. Configure RBAC permissions
3. Deploy the Logic App workflow definition automatically
4. Enable the Logic App

## Configuration

### Variables

You can customize the deployment by modifying `variables.tf` or providing values:

```bash
terraform apply \
  -var="environment=prod" \
  -var="location=East US" \
  -var='resource_tags={"Department":"IT","CostCenter":"12345"}'
```

### Available Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `environment` | Environment name (dev/test/stage/prod) | `dev` |
| `location` | Azure region | `Central US` |
| `resource_tags` | Tags for all resources | See variables.tf |
| `subscription_id` | Subscription to monitor (optional) | Current subscription |
| `storage_replication_type` | Storage replication | `LRS` |

## Post-Deployment

### View Deployed Resources

```bash
terraform output
```

### Manually Trigger Logic App

```bash
# Get the trigger command from outputs
terraform output logic_app_trigger_url

# Or run directly
az rest --method POST \
  --uri "https://management.azure.com/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Logic/workflows/{logic-app-name}/triggers/DailySchedule/run?api-version=2016-06-01"
```

### View Logic App in Azure Portal

```bash
terraform output view_logic_app_portal
```

### Check Logic App Run History

```bash
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/{subscription-id}/resourceGroups/{rg-name}/providers/Microsoft.Logic/workflows/{logic-app-name}/runs?api-version=2017-07-01"
```

### Download JSON Reports

```bash
az storage blob list \
  --account-name {storage-account-name} \
  --container-name advisor-recommendations \
  --auth-mode login

az storage blob download \
  --account-name {storage-account-name} \
  --container-name advisor-recommendations \
  --name advisor-recommendations-2025-11-18-060000.json \
  --file ./advisor-report.json \
  --auth-mode login
```

## Workflow Definition

The workflow is deployed from `workflow-definition.json.tpl` and includes:

- **Daily Schedule**: Recurrence trigger at 6:00 AM UTC
- **Variable Initialization**: Date, filename, recommendations array, nextLink
- **Pagination Loop**: Until loop that fetches all pages using $skiptoken
- **API Calls**: Queries Azure Advisor with managed identity, handles multiple pages
- **Data Collection**: Appends recommendations from each page to array
- **Storage Upload**: Writes complete JSON with all recommendations to blob storage

## Updating the Workflow

To update the workflow definition:

1. Modify `workflow-definition.json.tpl`
2. Run `terraform apply`
3. Terraform will detect changes and redeploy the workflow

## Troubleshooting

### Workflow Deployment Fails

If the null_resource provisioner fails:

```bash
# Check Azure CLI authentication
az account show

# Manually deploy workflow using the template
cd terraform
az rest --method PUT \
  --uri "$(terraform output -raw logic_app_id)?api-version=2019-05-01" \
  --body @workflow-payload.json
```

### Permission Issues

Ensure the managed identity has proper roles:

```bash
# Check role assignments
az role assignment list \
  --assignee {managed-identity-principal-id} \
  --all
```

### Logic App Not Running

```bash
# Check Logic App state
az logic workflow show \
  --resource-group {rg-name} \
  --name {logic-app-name} \
  --query "state"

# Enable if disabled
az logic workflow update \
  --resource-group {rg-name} \
  --name {logic-app-name} \
  --state Enabled
```

## Clean Up

To remove all resources:

```bash
terraform destroy
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                 Daily Schedule                       │
│              (6:00 AM UTC Trigger)                   │
└───────────────────┬─────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│           Initialize Variables                       │
│  (Date, Filename, AllRecommendations, NextLink)     │
└───────────────────┬─────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│         Until Loop (No More Pages)                  │
│  ┌───────────────────────────────────────────────┐ │
│  │  Query Azure Advisor API Page                 │ │
│  │  (Managed Identity + $skiptoken)              │ │
│  └──────────────┬────────────────────────────────┘ │
│                 ▼                                    │
│  ┌───────────────────────────────────────────────┐ │
│  │  Parse Response & Extract nextLink            │ │
│  └──────────────┬────────────────────────────────┘ │
│                 ▼                                    │
│  ┌───────────────────────────────────────────────┐ │
│  │  ForEach: Append Recommendations to Array     │ │
│  └──────────────┬────────────────────────────────┘ │
│                 ▼                                    │
│  ┌───────────────────────────────────────────────┐ │
│  │  Update NextLink Variable                     │ │
│  └───────────────────────────────────────────────┘ │
└───────────────────┬─────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│        Upload JSON to Blob Storage                  │
│  (Complete recommendations array with metadata)     │
└─────────────────────────────────────────────────────┘
```

## Support

For issues or questions:
1. Check Azure Logic App run history in the portal
2. Review Terraform state: `terraform show`
3. Check Azure activity logs
4. Validate managed identity permissions