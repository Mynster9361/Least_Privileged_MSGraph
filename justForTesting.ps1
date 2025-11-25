#Requires -Module EntraAuth
param(
  [string]$tenantId,
  [string]$clientId,
  [SecureString]$clientSecret,
  [string]$logAnalyticsWorkspaceId,
  [int]$daysToQuery = 30
)


#region temp implementation to load in all functions in the clean folder
Import-Module .\output\module\LeastPrivilegedMSGraph\0.1.0\LeastPrivilegedMSGraph.psd1
#endregion temp implementation to load in all functions in the clean folder


#region Initialize log analytics service and connect to msgraph,LogAnalytics with app read all permission
Initialize-LogAnalyticsApi

Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret -Service "LogAnalytics", "GraphBeta"

#endregion Initialize log analytics service and connect to msgraph,LogAnalytics with app read all permission

#region the good stuff
$lightweightGroups = Get-AppRoleAssignment | Select-Object -First 5

$lightweightGroups | Get-AppActivityData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery

$lightweightGroups | Get-AppThrottlingData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery

$lightweightGroups | Get-PermissionAnalysis

Export-PermissionAnalysisReport -AppData $lightweightGroups -OutputPath ".\report.html"

#endregion the good stuff

#region full pipeline

# PIPE EVERYTHING!!!!
Get-AppRoleAssignment |
  Select-Object -First 7 |
    Get-AppActivityData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery |
      Get-AppThrottlingData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery |
        Get-PermissionAnalysis |
          Export-PermissionAnalysisReport -OutputPath ".\report5.html"


#endregion full pipeline
