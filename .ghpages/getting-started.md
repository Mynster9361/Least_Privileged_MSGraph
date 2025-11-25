---
layout: page
title: Getting Started
permalink: /getting-started
---

# Getting Started with LeastPrivilegedMSGraph

This guide will help you install and configure the LeastPrivilegedMSGraph module.

## Prerequisites

- PowerShell 5.1 or PowerShell 7+
- Azure Active Directory (Entra ID) tenant
- Log Analytics workspace (for API usage data)
- Appropriate permissions to read application data

## Installation

### From PowerShell Gallery (Recommended)

```powershell
# Install the module
Install-Module -Name LeastPrivilegedMSGraph -Repository PSGallery -Scope CurrentUser

# Verify installation
Get-Module -Name LeastPrivilegedMSGraph -ListAvailable
```

### From Source

```powershell
# Clone the repository
git clone https://github.com/Mynster9361/Least_Privileged_MSGraph.git

# Import the module
Import-Module ./Least_Privileged_MSGraph/output/module/LeastPrivilegedMSGraph
```

## Configuration

### 1. Set Up Log Analytics

First, you need to configure your Log Analytics workspace connection:

```powershell
# Initialize the Log Analytics API connection
Initialize-LogAnalyticsApi -WorkspaceId "your-workspace-id" -SharedKey "your-shared-key"
```

{% include alert.html type="warning" title="Security Note" content="Store your shared key securely. Consider using Azure Key Vault or environment variables instead of hardcoding credentials." %}

### 2. Verify Connection

Test your configuration:

```powershell
# Get activity data for an application
Get-AppActivityData -ApplicationId "your-app-id" -Days 30
```

## Basic Usage

### Analyze Application Permissions

```powershell
# Get permission analysis
$analysis = Get-PermissionAnalysis -ApplicationId "12345678-1234-1234-1234-123456789abc"

# Display recommended permissions
$analysis.RecommendedPermissions

# Display currently assigned permissions
$analysis.CurrentPermissions

# Show over-privileged permissions
$analysis.OverPrivilegedPermissions
```

### Generate Reports

```powershell
# Export detailed analysis report
Export-PermissionAnalysisReport `
    -ApplicationId "12345678-1234-1234-1234-123456789abc" `
    -OutputPath "./reports" `
    -Format HTML

# Export as JSON for automation
Export-PermissionAnalysisReport `
    -ApplicationId "12345678-1234-1234-1234-123456789abc" `
    -OutputPath "./reports" `
    -Format JSON
```

### Monitor Application Activity

```powershell
# Get recent activity data
Get-AppActivityData -ApplicationId "12345678-1234-1234-1234-123456789abc" -Days 7

# Check for throttling issues
Get-AppThrottlingData -ApplicationId "12345678-1234-1234-1234-123456789abc"

# Get role assignments
Get-AppRoleAssignment -ApplicationId "12345678-1234-1234-1234-123456789abc"
```

## Next Steps

- Explore the [Command Reference](commands) for detailed cmdlet documentation
- Check out [Examples](examples) for common scenarios
- Review [best practices](#) for permission management

## Troubleshooting

### Common Issues

**Module not found after installation:**
```powershell
# Refresh module cache
Get-Module -ListAvailable -Refresh
```

**Authentication errors:**
- Verify your Log Analytics workspace ID and shared key
- Ensure you have appropriate permissions in Azure AD
- Check that your Azure subscription is active

**No data returned:**
- Verify the application ID is correct
- Ensure the application has been active in the specified time period
- Check that diagnostic logs are enabled for your tenant

## Getting Help

```powershell
# Get help for any cmdlet
Get-Help Get-PermissionAnalysis -Full

# List all available commands
Get-Command -Module LeastPrivilegedMSGraph
```

Need more help? [Open an issue on GitHub](https://github.com/Mynster9361/Least_Privileged_MSGraph/issues).
