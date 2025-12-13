#Requires -Module EntraAuth
param(
  [string]$tenantId,
  [string]$clientId,
  [SecureString]$clientSecret,
  [string]$logAnalyticsWorkspaceId,
  [int]$daysToQuery = 30
)


#region temp implementation to load in all functions in the clean folder
./build.ps1 -ResolveDependency -tasks clean, build
Import-Module .\output\module\LeastPrivilegedMSGraph\0.1.2\LeastPrivilegedMSGraph.psd1 -Force -Verbose
#endregion temp implementation to load in all functions in the clean folder


#region Initialize log analytics service and connect to msgraph,LogAnalytics with app read all permission
Initialize-LogAnalyticsApi

Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret -Service "LogAnalytics", "GraphBeta"

#endregion Initialize log analytics service and connect to msgraph,LogAnalytics with app read all permission

#region the good stuff
Measure-Command {
  $lightweightGroups = Get-AppRoleAssignment | select -first 10

  $lightweightGroups | Get-AppActivityData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery -ThrottleLimit 20

  $lightweightGroups | Get-AppThrottlingData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery

  $lightweightGroups | Get-PermissionAnalysis

  Export-PermissionAnalysisReport -AppData $lightweightGroups -OutputPath ".\report.html"
}

$t = $lightweightGroups | where-object {$_.PrincipalName -eq ""}
$t | Get-AppActivityData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery
$t | Get-AppThrottlingData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery
$t | Get-PermissionAnalysis

Get-AppActivityFromLog -logAnalyticsWorkspace $logAnalyticsWorkspaceId -days 30 -spId "" -Debug -Verbose
<# Before Freds suggestions
Days              : 0
Hours             : 0
Minutes           : 23
Seconds           : 24
Milliseconds      : 616
Ticks             : 14046166944
TotalDays         : 0,0162571376666667
TotalHours        : 0,390171304
TotalMinutes      : 23,41027824
TotalSeconds      : 1404,6166944
TotalMilliseconds : 1404616,6944

#>

<# After Freds suggestions
Days              : 0
Hours             : 0
Minutes           : 12
Seconds           : 56
Milliseconds      : 76
Ticks             : 7760765648
TotalDays         : 0,00898236764814815
TotalHours        : 0,215576823555556
TotalMinutes      : 12,9346094133333
TotalSeconds      : 776,0765648
TotalMilliseconds : 776076,5648
#>

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
