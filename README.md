# Azure Advisor Automation

This project automates the collection of Azure Advisor recommendations using Azure Logic Apps. The solution runs on a daily schedule, queries the Azure Advisor APIs, and stores the recommendations as CSV files in Azure Storage.

## 🏗️ Architecture Overview

![Architecture Diagram](docs/architecture-diagram.png)

The solution consists of:
- **Logic App (Standard)**: Orchestrates the daily collection workflow
- **Managed Identity**: Provides secure authentication to Azure APIs
- **Storage Account**: Stores CSV output files with recommendations
- **App Service Plan**: Hosts the Logic App runtime
- **Role Assignments**: Provides necessary permissions for API access

## ✨ Features

- **Daily Automated Collection**: Runs at 6:00 AM UTC daily
- **Secure Authentication**: Uses Azure Managed Identity (no secrets required)
- **CSV Output**: Structured data for easy analysis and reporting
- **Error Handling**: Robust error handling and retry logic
- **Infrastructure as Code**: Deploy with Bicep or Terraform
- **Cost Optimized**: Uses consumption-based Logic App Standard tier

## 📋 Prerequisites

Before deploying this solution, ensure you have:

1. **Azure Subscription** with appropriate permissions:
   - Contributor role on the target resource group
   - User Access Administrator role (for role assignments)

2. **Development Tools** (choose one deployment method):
   - [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (for Bicep)
   - [Terraform](https://www.terraform.io/downloads) (for Terraform)
   - [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell) (optional)

3. **Required Azure Resource Providers** (usually pre-registered):
   - Microsoft.Logic
   - Microsoft.Storage
   - Microsoft.Web
   - Microsoft.ManagedIdentity

## 🚀 Quick Start

### Option 1: Deploy with Bicep

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd AdvisorAutomation
   ```

2. **Login to Azure**:
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

3. **Create a resource group**:
   ```bash
   az group create --name "rg-advisor-automation-dev" --location "East US 2"
   ```

4. **Deploy the infrastructure**:
   ```bash
   cd bicep
   az deployment group create \
     --resource-group "rg-advisor-automation-dev" \
     --template-file main.bicep \
     --parameters main.bicepparam
   ```

### Option 2: Deploy with Terraform

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd AdvisorAutomation/terraform
   ```

2. **Configure variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

3. **Initialize and deploy**:
   ```bash
   terraform init
   terraform validate
   terraform plan
   terraform apply
   ```

## 📊 Output Data Structure

The generated CSV files contain the following columns:

| Column | Description | Example |
|--------|-------------|---------|
| SubscriptionId | Azure subscription ID | `12345678-1234-1234-1234-123456789012` |
| ResourceGroup | Resource group name | `rg-production-web` |
| ResourceName | Azure resource name | `vm-web-01` |
| ResourceType | Azure resource type | `Microsoft.Compute/virtualMachines` |
| RecommendationId | Unique recommendation ID | `rec-12345678` |
| Category | Recommendation category | `Cost`, `Security`, `Performance`, `Reliability` |
| Impact | Impact level | `High`, `Medium`, `Low` |
| ShortDescription | Brief description | `Resize or shutdown underutilized virtual machines` |
| Description | Detailed description | `Your virtual machine is underutilized...` |
| RecommendationText | Action to take | `Consider resizing to a smaller VM size...` |
| LastUpdated | When recommendation was last updated | `2024-01-15T10:30:00Z` |
| SuppressionIds | List of suppression IDs | `supp-123;supp-456` |

## 📁 File Naming Convention

CSV files are automatically named using the pattern:
```
advisor-recommendations-YYYY-MM-DD.csv
```

Examples:
- `advisor-recommendations-2024-01-15.csv`
- `advisor-recommendations-2024-01-16.csv`

## 🔧 Configuration

### Environment Variables

The Logic App uses the following application settings:

| Setting | Description | Default |
|---------|-------------|---------|
| `WORKFLOWS_SUBSCRIPTION_ID` | Target subscription for recommendations | Current subscription |
| `WORKFLOWS_STORAGE_ACCOUNT_NAME` | Storage account for CSV output | Created during deployment |
| `WORKFLOWS_CONTAINER_NAME` | Storage container name | `advisor-recommendations` |

### Customizing the Schedule

To modify the execution schedule, update the Logic App workflow trigger:

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

## 🔐 Security

### Authentication & Authorization

- **Managed Identity**: Eliminates the need for stored credentials
- **RBAC Permissions**: Minimal required permissions assigned
  - Reader role on subscription (for Advisor API access)
  - Storage Blob Data Contributor on storage account
- **Network Security**: Storage account configured with secure defaults
- **TLS Encryption**: All communications use TLS 1.2+

### Data Protection

- **Encryption at Rest**: Storage account uses Microsoft-managed keys
- **Encryption in Transit**: HTTPS-only access enforced
- **Access Control**: Private storage containers, no public access
- **Retention**: 30-day retention policy for blobs

## 📈 Monitoring & Troubleshooting

### Logic App Monitoring

1. **Azure Portal**: Navigate to Logic App → Workflow → Run History
2. **Application Insights**: Enable for detailed telemetry
3. **Azure Monitor**: Set up alerts for failed runs

### Common Issues

| Issue | Cause | Solution |
|-------|-------|---------|
| Authentication errors | Insufficient permissions | Verify role assignments |
| Storage write failures | Storage account access | Check managed identity permissions |
| Advisor API errors | API rate limits | Implement exponential backoff |
| Empty results | No recommendations | Verify subscription has resources |

### Debugging Steps

1. **Check Logic App Run History**:
   ```bash
   az logicapp show --name "your-logic-app" --resource-group "your-rg"
   ```

2. **Verify Role Assignments**:
   ```bash
   az role assignment list --assignee "managed-identity-principal-id"
   ```

3. **Test Storage Access**:
   ```bash
   az storage blob list --account-name "your-storage" --container-name "advisor-recommendations"
   ```

## 💰 Cost Estimation

### Monthly Cost Breakdown (East US 2, approximate)

| Resource | Usage | Monthly Cost |
|----------|-------|-------------|
| Logic App Standard (WS1) | 744 hours | ~$150 |
| Storage Account (LRS) | 1 GB data, minimal transactions | ~$0.05 |
| Managed Identity | Included | Free |
| **Total** | | **~$150** |

### Cost Optimization Tips

1. **Right-size Logic App**: Start with WS1, monitor usage
2. **Storage Tier**: Use Cool tier for long-term archival
3. **Retention Policy**: Implement lifecycle management
4. **Resource Tagging**: Enable cost tracking and allocation

## 🔄 Maintenance

### Regular Tasks

- **Monthly**: Review Logic App performance and costs
- **Quarterly**: Update Bicep/Terraform templates
- **Annually**: Review and update role assignments

### Upgrade Path

1. **Update Templates**: Pull latest changes from repository
2. **Test in Development**: Deploy to test environment first
3. **Plan Deployment**: Schedule maintenance window
4. **Deploy**: Use Infrastructure as Code for consistent updates

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:

1. **GitHub Issues**: Create an issue for bugs or feature requests
2. **Documentation**: Check the `/docs` folder for detailed guides
3. **Azure Support**: For Azure-specific issues, contact Azure Support

## 📚 Additional Resources

- [Azure Advisor Documentation](https://docs.microsoft.com/en-us/azure/advisor/)
- [Logic Apps Documentation](https://docs.microsoft.com/en-us/azure/logic-apps/)
- [Azure Managed Identity](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

---

**Created with ❤️ for the Azure community**