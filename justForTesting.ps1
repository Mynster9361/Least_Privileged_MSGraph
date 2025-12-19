#Requires -Module EntraAuth
param(
  [string]$tenantId,
  [string]$clientId,
  [SecureString]$clientSecret,
  [string]$logAnalyticsWorkspaceId,
  [int]$daysToQuery = 30
)
$tenantId = "your tenant id"
$clientId = "your client id"
$clientSecret = "your secret" | ConvertTo-SecureString -AsPlainText -Force
$daysToQuery = 5
$logAnalyticsWorkspaceId = "your workspace id"

#region temp implementation to load in all functions in the clean folder
./build.ps1 -ResolveDependency -tasks clean, build, test
Import-Module .\output\module\LeastPrivilegedMSGraph\1.0.0\LeastPrivilegedMSGraph.psd1 -Force -Verbose
#endregion temp implementation to load in all functions in the clean folder


#region Initialize log analytics service and connect to msgraph,LogAnalytics with app read all permission
Initialize-LogAnalyticsApi


#endregion Initialize log analytics service and connect to msgraph,LogAnalytics with app read all permission

#region the good stuff
Measure-Command {

  Connect-EntraService -Service "LogAnalytics", "GraphBeta" -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret

  $lightweightGroups = Get-AppRoleAssignment | Select-Object -First 5

  $lightweightGroups | Get-AppActivityData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery -ThrottleLimit 20 -MaxActivityEntries 1000 -Verbose -Debug

  $lightweightGroups | Get-AppThrottlingData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery

  $lightweightGroups | Get-PermissionAnalysis

  Export-PermissionAnalysisReport -AppData $lightweightGroups -OutputPath ".\report2.html"
}
#endregion the good stuff

#region test app activty data
# Get one app to test with
$testApp = (Get-AppRoleAssignment | Select-Object -First 1)

# Call Get-AppActivityFromLog directly
$activity = Get-AppActivityFromLog -subId "your subscription id" `
  -rgName "your rg name" `
  -workspaceName "your workspace name" `
  -spId "spid" `
  -days 5 `
  -maxActivityEntries 100 `
  -Verbose -Debug

# Check all PSFramework messages
Get-PSFMessage | Select-Object -Last 30 | Format-Table Timestamp, FunctionName, Level, Message -AutoSize
#endregion test app activty data

#region the good stuff for user context
Initialize-LogAnalyticsApi
Connect-EntraService -Service "LogAnalytics", "GraphBeta" -AsAzAccount
$subscriptionId = "your subscription id"
$resourceGroup = "your rg name"
$workspace = "your workspace name"
$daysToQuery = 5
$lightweightGroups = Get-AppRoleAssignment
$lightweightGroups | Get-AppActivityData -subId $subscriptionId -rgName $resourceGroup -workspaceName $workspace -Days $daysToQuery -ThrottleLimit 20 -MaxActivityEntries 1000 -Verbose -Debug

$lightweightGroups | Get-AppThrottlingData -subId $subscriptionId -rgName $resourceGroup -workspaceName $workspace -Days $daysToQuery -Verbose -Debug

$lightweightGroups | Get-PermissionAnalysis

Export-PermissionAnalysisReport -AppData $lightweightGroups -OutputPath ".\report.html"
#endregion the good stuff for user context

$t = $lightweightGroups | Where-Object { $_.PrincipalName -eq "" }
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
  Get-AppActivityData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery |
    Get-AppThrottlingData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery |
      Get-PermissionAnalysis |
        Export-PermissionAnalysisReport -OutputPath ".\report5.html"


#endregion full pipeline


#region testing the new assert + invoke-lpmsgraphscan
Initialize-LogAnalyticsApi
Connect-EntraService -Service "LogAnalytics", "GraphBeta", "Azure" -AsAzAccount
(Assert-LPMSGraph).checks
$subscriptionId = "your subscription id"
$resourceGroup = "your rg name"
$workspace = "your workspace name"
$paramUser = @{
  subId              = $subscriptionId
  rgName             = $resourceGroup
  workspaceName      = $workspace
  Days               = 5
  ThrottleLimit      = 20
  MaxActivityEntries = 1000
  OutputPath         = ".\report-invokelpmsgraphscan.html"
  Verbose            = $true
  Debug              = $true
}
Invoke-LPMSGraphScan @paramUser

$tenantId = "your tenant id"
$clientId = "your client id"
$clientSecret = "your secret" | ConvertTo-SecureString -AsPlainText -Force
$logAnalyticsWorkspaceId = "your workspace id"
Connect-EntraService -Service "LogAnalytics", "GraphBeta" -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret
$paramApp = @{
  WorkspaceId        = $logAnalyticsWorkspaceId
  Days               = 5
  ThrottleLimit      = 20
  MaxActivityEntries = 100
  OutputPath         = ".\report-invokelpmsgraphscan-app.html"
  Verbose            = $true
  Debug              = $true
}
#endregion testing the new assert + invoke-lpmsgraphscan
