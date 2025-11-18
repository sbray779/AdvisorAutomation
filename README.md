# Azure Advisor Automation

This project automates the collection of Azure Advisor recommendations using Azure Logic Apps. The solution runs on a daily schedule, queries the Azure Advisor APIs with automatic pagination, and stores the complete recommendations as JSON files in Azure Storage.

## 🏗️ Architecture Overview

The solution consists of:
- **Logic App (Consumption)**: Orchestrates the daily collection workflow with pagination support
- **Managed Identity**: Provides secure authentication to Azure APIs
- **Storage Account**: Stores JSON output files with recommendations
- **Role Assignments**: Provides necessary permissions for API access

## ✨ Features

- **Daily Automated Collection**: Runs at 6:00 AM UTC daily
- **Automatic Pagination**: Handles large result sets using Azure Advisor API pagination ($skiptoken)
- **Secure Authentication**: Uses Azure Managed Identity (no secrets required)
- **JSON Output**: Complete raw recommendation data for maximum flexibility
- **Error Handling**: Robust pagination loop with 100-iteration limit and 1-hour timeout
- **Infrastructure as Code**: Fully automated Terraform deployment
- **Cost Optimized**: Uses consumption-based Logic App pricing (pay per execution)

## 📋 Prerequisites

Before deploying this solution, ensure you have:

1. **Azure Subscription** with appropriate permissions:
   - Contributor role on the target resource group
   - User Access Administrator role (for role assignments)

2. **Development Tools**:
   - [Terraform](https://www.terraform.io/downloads) v1.5 or higher
   - [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
   - [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell) (for deployment scripts)

3. **Required Azure Resource Providers** (usually pre-registered):
   - Microsoft.Logic
   - Microsoft.Storage
   - Microsoft.ManagedIdentity

## 🚀 Quick Start - Terraform Deployment

Terraform deploys **both infrastructure and the complete workflow definition** automatically!

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd AdvisorAutomation/terraform
   ```

2. **Login to Azure**:
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

3. **Initialize and deploy**:
   ```bash
   terraform init
   terraform validate
   terraform plan
   terraform apply
   ```

The Terraform deployment automatically:
- Creates all infrastructure resources (Logic App, Storage, Managed Identity)
- Deploys the complete Logic App workflow definition with pagination
- Configures all triggers, actions, and managed identity authentication
- Sets up role assignments for secure API access (Reader on subscription, Storage Blob Data Contributor)

**No manual workflow deployment required!**

See [terraform/README.md](./terraform/README.md) for detailed deployment instructions and troubleshooting.

## 📊 Output Data Structure

The workflow generates JSON files with the following structure:

```json
{
  "collectedAt": "2025-11-18T06:00:00Z",
  "subscriptionId": "12345678-1234-1234-1234-123456789012",
  "recommendationCount": 150,
  "recommendations": [
    {
      "id": "/subscriptions/.../providers/Microsoft.Advisor/recommendations/...",
      "name": "recommendation-guid",
      "type": "Microsoft.Advisor/recommendations",
      "properties": {
        "category": "Cost",
        "impact": "High",
        "impactedField": "Microsoft.Compute/virtualMachines",
        "impactedValue": "vm-web-01",
        "lastUpdated": "2025-11-17T10:30:00Z",
        "recommendationTypeId": "...",
        "shortDescription": {
          "problem": "Underutilized virtual machine",
          "solution": "Resize or shutdown virtual machine"
        },
        "extendedProperties": {},
        "resourceMetadata": {
          "resourceId": "/subscriptions/.../resourceGroups/rg-prod/providers/Microsoft.Compute/virtualMachines/vm-web-01"
        }
      }
    }
  ]
}
```

### Key Fields

| Field | Description |
|-------|-------------|
| `collectedAt` | Timestamp when recommendations were collected |
| `subscriptionId` | Azure subscription ID |
| `recommendationCount` | Total number of recommendations |
| `recommendations[]` | Array of all recommendation objects from Azure Advisor API |

Each recommendation contains the complete Azure Advisor API response with category, impact, affected resources, and detailed guidance.

## 📁 File Naming Convention

JSON files are automatically named using the pattern:
```
advisor-recommendations-YYYY-MM-DD-HHmmss.json
```

Examples:
- `advisor-recommendations-2025-11-18-060000.json`
- `advisor-recommendations-2025-11-19-060000.json`

## 🔄 How Pagination Works

The Logic App workflow handles large result sets automatically:

1. **Initial Request**: Queries Azure Advisor API for recommendations
2. **Parse Response**: Extracts recommendations and checks for `nextLink` property
3. **Loop**: While `nextLink` exists, fetch next page and append to results array
4. **Complete**: When no more pages, save all recommendations to JSON blob

The workflow uses an `Until` loop with:
- **100 iteration limit**: Prevents infinite loops
- **1-hour timeout**: Ensures workflow doesn't run indefinitely
- **$skiptoken handling**: Azure Advisor API returns proper continuation tokens in `nextLink`

## 🔧 Configuration

### Modifying the Schedule

To change the execution schedule, update the workflow trigger in `terraform/workflow-definition.json.tpl`:

```json
{
  "type": "Recurrence",
  "recurrence": {
    "frequency": "Day",
    "interval": 1,
    "timeZone": "UTC",
    "startTime": "2024-01-01T06:00:00Z"
  }
}
```

Available frequency options: `Day`, `Week`, `Month`, `Hour`, `Minute`

After modifying, redeploy with `terraform apply`.

### Changing Target Subscription

Update the `subscription_id` variable in `terraform/main.tf` or provide at deployment:

```bash
terraform apply -var="subscription_id=your-subscription-id"
```

## 🔐 Security

### Authentication & Authorization

- **Managed Identity**: Eliminates the need for stored credentials
- **RBAC Permissions**: Minimal required permissions assigned
  - Reader role on subscription (for Advisor API access)
  - Storage Blob Data Contributor on storage account (for blob write access)
- **Network Security**: Storage account configured with secure defaults
- **TLS Encryption**: All communications use TLS 1.2+

### Data Protection

- **Encryption at Rest**: Storage account uses Microsoft-managed keys
- **Encryption in Transit**: HTTPS-only access enforced
- **Access Control**: Private storage containers, no public access

## 📈 Monitoring & Troubleshooting

### Viewing Logic App Run History

**Option 1: Azure Portal**
```
Navigate to: Logic App → Run History
```

**Option 2: Azure CLI**
```bash
# Get latest run
az resource show \
  --ids "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Logic/workflows/{logic-app-name}" \
  --query "properties.state"
```

**Option 3: Manual Trigger** (for testing)
```bash
az rest --method POST \
  --uri "https://management.azure.com/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Logic/workflows/{logic-app-name}/triggers/DailySchedule/run?api-version=2016-06-01"
```

### Viewing Output Files

```bash
# List all recommendation files
az storage blob list \
  --account-name {storage-account-name} \
  --container-name advisor-recommendations \
  --auth-mode login \
  --output table

# Download a specific file
az storage blob download \
  --account-name {storage-account-name} \
  --container-name advisor-recommendations \
  --name advisor-recommendations-2025-11-18-060000.json \
  --file recommendations.json \
  --auth-mode login
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|---------|
| Workflow fails on "Until_No_More_Pages" | Array append issue | Ensure using latest workflow template with Foreach loop |
| Authentication errors | Insufficient permissions | Verify role assignments with `az role assignment list` |
| Storage write failures | Missing Storage Blob Data Contributor | Check managed identity has correct role on storage account |
| Empty recommendations array | No recommendations available | Normal if subscription has no advisor recommendations |
| Pagination not working | Incorrect nextLink handling | Verify workflow uses `nextLink` property from API response |

## 💰 Cost Estimation

### Monthly Cost Breakdown (Central US, approximate)

| Resource | Usage | Monthly Cost |
|----------|-------|-------------|
| Logic App (Consumption) | 30 executions/month | ~$0.00* |
| Storage Account (LRS) | 1 GB data, minimal transactions | ~$0.05 |
| Managed Identity | Included | Free |
| **Total** | | **< $1/month** |

*First 4,000 workflow actions per month are free. A single daily run with 200 recommendations across 2 pages = ~8 actions/day × 30 days = 240 actions/month (well within free tier).

### Cost Optimization Tips

1. **Consumption vs Standard**: Consumption tier is ideal for scheduled workloads
2. **Storage Tier**: Use Cool tier for long-term archival (lifecycle management)
3. **Retention Policy**: Implement automatic deletion of old files if not needed
4. **Resource Tagging**: Enable cost tracking and allocation

## 🔄 Maintenance

### Regular Tasks

- **Monthly**: Review Logic App run history for failures
- **Quarterly**: Review and update Terraform templates
- **As Needed**: Update workflow logic for API changes

### Updating the Workflow

1. **Modify Template**: Edit `terraform/workflow-definition.json.tpl`
2. **Test Locally**: Validate JSON syntax
3. **Deploy**: Run `terraform apply`
4. **Verify**: Check Logic App run history after next scheduled run

## 🛠️ Project Structure

```
AdvisorAutomation/
├── .github/
│   └── copilot-instructions.md    # GitHub Copilot context
├── scripts/
│   └── deploy-workflow.ps1        # Manual workflow deployment script
├── terraform/
│   ├── main.tf                    # Main infrastructure configuration
│   ├── variables.tf               # Variable definitions
│   ├── outputs.tf                 # Output values
│   ├── workflow-definition.json.tpl # Logic App workflow template
│   ├── deploy-workflow.ps1        # Terraform helper script
│   └── README.md                  # Terraform-specific documentation
└── README.md                      # This file
```

## 📝 What's Changed (Latest Updates)

### Recent Improvements

✅ **Switched to Consumption Logic Apps**: More cost-effective for scheduled workloads  
✅ **JSON Output**: Raw API data instead of parsed CSV for maximum flexibility  
✅ **Pagination Support**: Automatic handling of large result sets using `$skiptoken`  
✅ **Fully Automated Deployment**: Terraform deploys infrastructure + workflow in one step  
✅ **Simplified Architecture**: Removed App Service Plan dependency  
✅ **Removed Bicep Templates**: Terraform-only deployment for consistency  

### Breaking Changes from Previous Versions

- **Output Format**: Changed from CSV to JSON
- **Logic App Type**: Changed from Standard to Consumption
- **Deployment Method**: Bicep templates removed, Terraform only
- **File Naming**: Added timestamp with seconds for uniqueness

## 🤝 Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly in a dev environment
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For issues and questions:

1. **GitHub Issues**: Create an issue for bugs or feature requests
2. **Terraform Documentation**: See [terraform/README.md](./terraform/README.md)
3. **Azure Support**: For Azure-specific issues, contact Azure Support

## 📚 Additional Resources

- [Azure Advisor Documentation](https://docs.microsoft.com/en-us/azure/advisor/)
- [Azure Advisor REST API Reference](https://docs.microsoft.com/en-us/rest/api/advisor/)
- [Logic Apps Documentation](https://docs.microsoft.com/en-us/azure/logic-apps/)
- [Azure Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

---

**Last Updated**: November 2025  
**Version**: 2.0 (JSON output with pagination)
