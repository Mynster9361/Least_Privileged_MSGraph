---
layout: page
title: Command Reference
permalink: /commands
---

# Command Reference

Complete reference documentation for all cmdlets in the LeastPrivilegedMSGraph module.

## Core Cmdlets

### Permission Analysis

- **[Get-LPMSPermissionAnalysis](commands/Get-LPMSPermissionAnalysis)** - Analyze application permissions and recommend least privileged access
- **[Export-LPMSPermissionAnalysisReport](commands/Export-LPMSPermissionAnalysisReport)** - Export detailed permission analysis reports

### Application Monitoring

- **[Get-LPMSAppActivityData](commands/Get-LPMSAppActivityData)** - Retrieve application API usage activity data
- **[Get-LPMSAppRoleAssignment](commands/Get-LPMSAppRoleAssignment)** - Get current role assignments for an application
- **[Get-LPMSAppThrottlingData](commands/Get-LPMSAppThrottlingData)** - Retrieve throttling and rate limit information

### Configuration

- **[Initialize-LPMSLogAnalyticsApi](commands/Initialize-LPMSLogAnalyticsApi)** - Initialize Log Analytics API connection

## Quick Reference

| Cmdlet                            | Description                       | Category      |
| --------------------------------- | --------------------------------- | ------------- |
| `Get-LPMSPermissionAnalysis`          | Analyze and recommend permissions | Analysis      |
| `Export-LPMSPermissionAnalysisReport` | Generate detailed reports         | Reporting     |
| `Get-LPMSAppActivityData`             | Get API usage data                | Monitoring    |
| `Get-LPMSAppRoleAssignment`           | List role assignments             | Monitoring    |
| `Get-LPMSAppThrottlingData`           | Check throttling status           | Monitoring    |
| `Initialize-LPMSLogAnalyticsApi`      | Setup Log Analytics               | Configuration |

## Usage Patterns

### Basic Analysis Workflow

```powershell
# 1. Initialize connection
Initialize-LPMSLogAnalyticsApi -WorkspaceId "..." -SharedKey "..."

# 2. Analyze permissions
$analysis = Get-LPMSPermissionAnalysis -ApplicationId "..."

# 3. Generate report
Export-LPMSPermissionAnalysisReport -ApplicationId "..." -OutputPath "./reports"
```

### Monitoring Workflow

```powershell
# Check activity
Get-LPMSAppActivityData -ApplicationId "..." -Days 30

# Check for issues
Get-LPMSAppThrottlingData -ApplicationId "..."

# Review assignments
Get-LPMSAppRoleAssignment -ApplicationId "..."
```

---

Browse individual command documentation using the navigation menu.
