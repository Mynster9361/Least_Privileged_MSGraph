---
layout: page
title: Examples
permalink: /examples
---

# Usage Examples

Common scenarios and code samples for using LeastPrivilegedMSGraph.

## Example 1: Basic Permission Analysis

Analyze permissions for a single application:

```powershell
# Initialize Log Analytics
Initialize-LogAnalyticsApi `
    -WorkspaceId "12345678-1234-1234-1234-123456789abc" `
    -SharedKey "your-shared-key"

# Analyze application
$appId = "app-id-here"
$analysis = Get-PermissionAnalysis -ApplicationId $appId

# Display results
Write-Host "Current Permissions: $($analysis.CurrentPermissions.Count)"
Write-Host "Recommended Permissions: $($analysis.RecommendedPermissions.Count)"
Write-Host "Over-Privileged: $($analysis.OverPrivilegedPermissions.Count)"
```

## Example 2: Batch Analysis with Reporting

Analyze multiple applications and generate reports:

```powershell
# List of applications to analyze
$applications = @(
    "app-id-1",
    "app-id-2",
    "app-id-3"
)

# Initialize connection
Initialize-LogAnalyticsApi -WorkspaceId $workspaceId -SharedKey $sharedKey

# Analyze each application
foreach ($appId in $applications) {
    Write-Host "Analyzing $appId..." -ForegroundColor Cyan
    
    # Get analysis
    $analysis = Get-PermissionAnalysis -ApplicationId $appId
    
    # Export report
    Export-PermissionAnalysisReport `
        -ApplicationId $appId `
        -OutputPath "./reports/$appId" `
        -Format HTML,JSON
    
    Write-Host "  Completed: $($analysis.RecommendedPermissions.Count) permissions recommended" -ForegroundColor Green
}
```

## Example 3: Monitoring Application Health

Monitor application activity and throttling:

```powershell
$appId = "your-app-id"

# Get last 7 days of activity
$activity = Get-AppActivityData -ApplicationId $appId -Days 7

# Check for throttling issues
$throttling = Get-AppThrottlingData -ApplicationId $appId

# Display summary
Write-Host "Activity Summary for $appId"
Write-Host "Total API Calls: $($activity.TotalCalls)"
Write-Host "Throttled Requests: $($throttling.ThrottledCount)"

if ($throttling.IsThrottled) {
    Write-Warning "Application is currently being throttled!"
}
```

## Example 4: Automated Compliance Check

Regular compliance checking with alerts:

```powershell
param(
    [string[]]$ApplicationIds,
    [string]$WorkspaceId,
    [string]$SharedKey,
    [string]$EmailTo
)

# Initialize
Initialize-LogAnalyticsApi -WorkspaceId $WorkspaceId -SharedKey $SharedKey

$overPrivilegedApps = @()

# Check each application
foreach ($appId in $ApplicationIds) {
    $analysis = Get-PermissionAnalysis -ApplicationId $appId
    
    if ($analysis.OverPrivilegedPermissions.Count -gt 0) {
        $overPrivilegedApps += [PSCustomObject]@{
            ApplicationId = $appId
            OverPrivilegedCount = $analysis.OverPrivilegedPermissions.Count
            Permissions = $analysis.OverPrivilegedPermissions
        }
    }
}

# Send alert if issues found
if ($overPrivilegedApps.Count -gt 0) {
    $body = $overPrivilegedApps | ConvertTo-Html | Out-String
    Send-MailMessage `
        -To $EmailTo `
        -Subject "Over-Privileged Applications Detected" `
        -Body $body `
        -BodyAsHtml
}
```

## Example 5: Export to Azure DevOps Pipeline

Integrate with CI/CD pipelines:

```powershell
# In your Azure DevOps pipeline
- task: PowerShell@2
  displayName: 'Analyze Application Permissions'
  inputs:
    targetType: 'inline'
    script: |
      Install-Module -Name LeastPrivilegedMSGraph -Force -Scope CurrentUser
      
      Initialize-LogAnalyticsApi `
        -WorkspaceId $(LogAnalyticsWorkspaceId) `
        -SharedKey $(LogAnalyticsSharedKey)
      
      $analysis = Get-PermissionAnalysis -ApplicationId $(ApplicationId)
      
      # Fail pipeline if over-privileged
      if ($analysis.OverPrivilegedPermissions.Count -gt 0) {
        Write-Error "Application has $($analysis.OverPrivilegedPermissions.Count) over-privileged permissions"
        exit 1
      }
      
      Export-PermissionAnalysisReport `
        -ApplicationId $(ApplicationId) `
        -OutputPath "$(Build.ArtifactStagingDirectory)/reports"
```

## More Examples

For more examples and advanced scenarios, check out:

- [GitHub Repository Examples](https://github.com/Mynster9361/Least_Privileged_MSGraph/tree/main/examples)
- [Community Contributions](https://github.com/Mynster9361/Least_Privileged_MSGraph/discussions)
