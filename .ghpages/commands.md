---
layout: page
title: Command Reference
permalink: /commands
---

# Command Reference

Complete reference documentation for all cmdlets in the LeastPrivilegedMSGraph module.

## Core Cmdlets

### Permission Analysis

- **[Get-PermissionAnalysis](commands/Get-PermissionAnalysis)** - Analyze application permissions and recommend least privileged access
- **[Export-PermissionAnalysisReport](commands/Export-PermissionAnalysisReport)** - Export detailed permission analysis reports

### Application Monitoring

- **[Get-AppActivityData](commands/Get-AppActivityData)** - Retrieve application API usage activity data
- **[Get-AppRoleAssignment](commands/Get-AppRoleAssignment)** - Get current role assignments for an application
- **[Get-AppThrottlingData](commands/Get-AppThrottlingData)** - Retrieve throttling and rate limit information

### Configuration

- **[Initialize-LogAnalyticsApi](commands/Initialize-LogAnalyticsApi)** - Initialize Log Analytics API connection

## Quick Reference

| Cmdlet                            | Description                       | Category      |
| --------------------------------- | --------------------------------- | ------------- |
| `Get-PermissionAnalysis`          | Analyze and recommend permissions | Analysis      |
| `Export-PermissionAnalysisReport` | Generate detailed reports         | Reporting     |
| `Get-AppActivityData`             | Get API usage data                | Monitoring    |
| `Get-AppRoleAssignment`           | List role assignments             | Monitoring    |
| `Get-AppThrottlingData`           | Check throttling status           | Monitoring    |
| `Initialize-LogAnalyticsApi`      | Setup Log Analytics               | Configuration |

## Usage Patterns

### Basic Analysis Workflow

```powershell
# 1. Initialize connection
Initialize-LogAnalyticsApi -WorkspaceId "..." -SharedKey "..."

# 2. Analyze permissions
$analysis = Get-PermissionAnalysis -ApplicationId "..."

# 3. Generate report
Export-PermissionAnalysisReport -ApplicationId "..." -OutputPath "./reports"
```

### Monitoring Workflow

```powershell
# Check activity
Get-AppActivityData -ApplicationId "..." -Days 30

# Check for issues
Get-AppThrottlingData -ApplicationId "..."

# Review assignments
Get-AppRoleAssignment -ApplicationId "..."
```

---

Browse individual command documentation using the navigation menu.
