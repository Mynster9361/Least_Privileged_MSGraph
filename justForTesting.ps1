#Requires -Module EntraAuth
param(
  [string]$tenantId,
  [string]$clientId,
  [SecureString]$clientSecret,
  [string]$logAnalyticsWorkspaceId,
  [int]$daysToQuery = 30
)

#TODO: Missing Permissions does not look at the Current Permissions at all right now, need to add that in

$tenantId = $env:tenantId
$clientId = $env:clientId
$clientSecret = $env:clientSecret | ConvertTo-SecureString -AsPlainText -Force
$daysToQuery = 5
$logAnalyticsWorkspaceId = $env:logAnalyticsWorkspaceId

#region temp implementation to load in all functions in the clean folder
./build.ps1 -ResolveDependency -tasks clean, build, test
Import-Module .\output\module\LeastPrivilegedMSGraph\3.0.0\LeastPrivilegedMSGraph.psd1 -Force -Verbose
#endregion temp implementation to load in all functions in the clean folder


#region Initialize log analytics service and connect to msgraph,LogAnalytics with app read all permission
Initialize-LPMSLogAnalyticsApi


#endregion Initialize log analytics service and connect to msgraph,LogAnalytics with app read all permission

#region the good stuff

Connect-EntraService -Service "LogAnalytics", "GraphBeta" -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret

$lightweightGroups = Get-LPMSAppRoleAssignment

$lightweightGroups[0..20] | Get-LPMSAppActivityData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery -ThrottleLimit 20 -MaxActivityEntries 1000 -Verbose -Debug

$lightweightGroups[0..20] | Get-LPMSAppThrottlingData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery

$groups = $lightweightGroups[0..20]
$groups | Get-LPMSPermissionAnalysis
#$lightweightGroups | Get-LPMSPermissionAnalysis

Export-LPMSPermissionAnalysisReport -AppData $groups -OutputPath ".\report2.html"

#endregion the good stuff

#region test delegated apps
./build.ps1 -ResolveDependency -tasks clean, build, test
Import-Module .\output\module\LeastPrivilegedMSGraph\2.0.0\LeastPrivilegedMSGraph.psd1 -Force -Verbose

Initialize-LPMSLogAnalyticsApi
Connect-EntraService -Service "LogAnalytics", "GraphBeta" -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret
$delegatedOnly = Get-LPMSAppRoleAssignment -Verbose
$delegatedOnly | Get-LPMSAppActivityData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery -ThrottleLimit 20 -MaxActivityEntries 10000 -Verbose -Debug
$delegatedOnly | Get-LPMSAppThrottlingData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery -Verbose -Debug
$delegatedOnly | Get-LPMSPermissionAnalysis -Verbose -Debug
Export-LPMSPermissionAnalysisReport -AppData $delegatedOnly -OutputPath ".\report-delegated.html"

$apps = Get-LPMSAppRoleAssignment |
  Get-LPMSAppActivityData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery -ThrottleLimit 20 -MaxActivityEntries 1000 |
    Get-LPMSPermissionAnalysis
$apps | Get-LPMSAppThrottlingData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery -Verbose -Debug
Export-LPMSPermissionAnalysisReport -AppData $apps -OutputPath ".\report-delegated-2.html"

#endregion test delegated apps

#region test app activty data
# Get one app to test with
$testApp = (Get-LPMSAppRoleAssignment | Select-Object -First 1)


# Check all PSFramework messages
Get-PSFMessage | Select-Object -Last 30 | Format-Table Timestamp, FunctionName, Level, Message -AutoSize
#endregion test app activty data

#region the good stuff for user context
Initialize-LPMSLogAnalyticsApi
Connect-EntraService -Service "LogAnalytics", "GraphBeta" -AsAzAccount
$daysToQuery = 5
$lightweightGroups = Get-LPMSAppRoleAssignment
$lightweightGroups | Get-LPMSAppActivityData -subId $subscriptionId -rgName $resourceGroup -workspaceName $workspace -Days $daysToQuery -ThrottleLimit 20 -MaxActivityEntries 1000 -Verbose -Debug

$lightweightGroups | Get-LPMSAppThrottlingData -subId $subscriptionId -rgName $resourceGroup -workspaceName $workspace -Days $daysToQuery -Verbose -Debug

$lightweightGroups | Get-LPMSPermissionAnalysis

Export-LPMSPermissionAnalysisReport -AppData $lightweightGroups -OutputPath ".\report.html"
#endregion the good stuff for user context

$t = $lightweightGroups | Where-Object { $_.PrincipalName -eq "" }
$t | Get-LPMSAppActivityData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery
$t | Get-LPMSAppThrottlingData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery
$t | Get-LPMSPermissionAnalysis

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
Get-LPMSAppRoleAssignment |
  Get-LPMSAppActivityData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery |
    Get-LPMSAppThrottlingData -WorkspaceId $logAnalyticsWorkspaceId -Days $daysToQuery |
      Get-LPMSPermissionAnalysis |
        Export-LPMSPermissionAnalysisReport -OutputPath ".\report5.html"


#endregion full pipeline


#region testing the new assert + invoke-lpmsgraphscan
Initialize-LPMSLogAnalyticsApi
Connect-EntraService -Service "LogAnalytics", "GraphBeta", "Azure" -AsAzAccount
(Assert-LPMSGraph).checks
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
