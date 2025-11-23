#Requires -Module EntraAuth
param(
  [string]$tenantId,
  [string]$clientId,
  [SecureString]$clientSecret,
  [string]$logAnalyticsWorkspaceId,
  [int]$daysToQuery = 30
)


#region temp implementation to load in all functions in the clean folder
$scriptDir = (get-location).Path
$cleanDir = Join-Path -Path $scriptDir -ChildPath "clean"
Get-ChildItem -Path $cleanDir -Recurse -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}
#endregion temp implementation to load in all functions in the clean folder


#region Initialize log analytics service and connect to msgraph,LogAnalytics with app read all permission
Initialize-LogAnalyticsApi

Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret -Service "LogAnalytics", "GraphBeta"

#endregion Initialize log analytics service and connect to msgraph,LogAnalytics with app read all permission

#region the good stuff
$lightweightGroups = Get-AppRoleAssignments | select -First 5

$lightweightGroups | Get-AppActivityData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery

$lightweightGroups | Get-AppThrottlingData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery

$lightweightGroups | Get-PermissionAnalysis

New-PermissionAnalysisReport -AppData $lightweightGroups -OutputPath ".\report.html"

#endregion the good stuff

#region full pipeline

# PIPE EVERYTHING!!!!
Get-AppRoleAssignments | 
    select -First 50 | 
    Get-AppActivityData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery |
    Get-AppThrottlingData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery |
    Get-PermissionAnalysis |
    New-PermissionAnalysisReport -OutputPath ".\report50.html"


#endregion full pipeline