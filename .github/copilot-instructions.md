# Azure Advisor Automation Project

This project automates the collection of Azure Advisor recommendations using a Logic App that runs on a daily schedule.

## Project Structure
- `/logic-app/` - Logic App workflow definitions and configurations
- `/bicep/` - Bicep Infrastructure as Code templates
- `/terraform/` - Terraform Infrastructure as Code templates
- `/docs/` - Documentation and deployment guides

## Key Components
- **Logic App**: Scheduled workflow to query Azure Advisor APIs daily
- **Storage Account**: CSV output storage for advisor recommendations
- **Managed Identity**: Secure authentication for API access
- **Resource Group**: Container for all related Azure resources

## Development Guidelines
- Use Managed Identity for all Azure resource authentication
- Follow Azure security best practices
- Implement proper error handling and retry logic
- Use parameterized templates for flexible deployments
- Include comprehensive logging and monitoring

## Deployment Options
- Bicep templates for Azure-native IaC
- Terraform templates for cross-cloud compatibility
- Both templates create identical infrastructure

This is an infrastructure automation project focused on Azure Advisor data collection and storage.