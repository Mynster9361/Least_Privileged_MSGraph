#Requires -Module EntraAuth
$tenantId = "replace with your tenant id" # replace with your tenant id
$clientId = "replace with your client id" # replace with your client id
$clientSecret = "replace with your client secret" # replace with your client secret

# Convert client secret to SecureString for EntraService connection
$clientSecretSecure = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force

$authUri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

# log analytics variables
$daysToQuery = 30
$logAnalyticsWorkspaceId = "replace with your log analytics workspace id" # replace with your log analytics workspace id

#region connect to msgraph with app read all permission

$LogAnalyticsCfg = @{
  Name          = 'LogAnalytics'
  ServiceUrl    = 'https://api.loganalytics.azure.com'
  Resource      = 'https://api.loganalytics.io'
  DefaultScopes = @()
  HelpUrl       = 'https://docs.microsoft.com/en-us/azure/azure-monitor/logs/api/overview'
  Header        = @{
    'Content-Type' = 'application/json'
  }
  NoRefresh     = $false
}
Register-EntraService @LogAnalyticsCfg

# Connect to Entra Service for Log Analytics
Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecretSecure -Service "LogAnalytics", "GraphBeta"

$lightweightGroups = Get-AppRoleAssignments

#endregion translate app role ids to permission names
#region lookup app activity in log analytics workspace
# Query activity for each app using EntraService
foreach ($app in $lightweightGroups[10..30]) {
  $spId = $app.PrincipalId
  try {
    $activity = Get-AppActivityFromLogs -logAnalyticsWorkspace $logAnalyticsWorkspaceId -days $daysToQuery -spId $spId
    if ($null -ne $activity) {
      $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value $activity -Force
    }
    else {
      $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
      Write-Debug "No activity found for $($app.PrincipalName)."
    }
  }
  catch {
    Write-Debug "Error retrieving activity for $($app.PrincipalName): $_"
    $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
  }
}

#endregion lookup app activity in log analytics workspace


#region compare app activity and permissions to the permissions map json to see if the app is using the permissions assigned to it



# Load permission maps once at the start
Write-Host "Loading permission maps..." -ForegroundColor Cyan
$permissionMapv1 = Get-Content -Path ".\data\sample\permissions-v1.0.json" -Raw | ConvertFrom-Json
$permissionMapbeta = Get-Content -Path ".\data\sample\permissions-beta.json" -Raw | ConvertFrom-Json

# Process each app
$lightweightGroups[10..30] | ForEach-Object {
  $app = $_

  Write-Host "`nAnalyzing: $($app.PrincipalName)" -ForegroundColor Cyan

  # Find least privileged permissions for each activity
  $splatLeastPrivileged = @{
    userActivity      = $app.Activity
    permissionMapv1   = $permissionMapv1
    permissionMapbeta = $permissionMapbeta
  }
  $activityPermissions = Find-LeastPrivilegedPermissions @splatLeastPrivileged

  # Get optimal permission set
  $optimalSet = Get-OptimalPermissionSet -activityPermissions $activityPermissions

  # Add results to app object
  $app | Add-Member -MemberType NoteProperty -Name "ActivityPermissions" -Value $activityPermissions -Force
  $app | Add-Member -MemberType NoteProperty -Name "OptimalPermissions" -Value $optimalSet.OptimalPermissions -Force
  $app | Add-Member -MemberType NoteProperty -Name "UnmatchedActivities" -Value $optimalSet.UnmatchedActivities -Force

  # Compare with current permissions
  $currentPermissions = $app.AppRoles | Select-Object -ExpandProperty FriendlyName | Where-Object { $_ -ne $null }
  $optimalPermissionNames = $optimalSet.OptimalPermissions | Select-Object -ExpandProperty Permission -Unique

  $excessPermissions = $currentPermissions | Where-Object { $optimalPermissionNames -notcontains $_ }
  $missingPermissions = $optimalPermissionNames | Where-Object { $currentPermissions -notcontains $_ }

  $app | Add-Member -MemberType NoteProperty -Name "CurrentPermissions" -Value $currentPermissions -Force
  $app | Add-Member -MemberType NoteProperty -Name "ExcessPermissions" -Value $excessPermissions -Force
  $app | Add-Member -MemberType NoteProperty -Name "RequiredPermissions" -Value $missingPermissions -Force
  if ($optimalSet.UnmatchedActivities) {
    $matchedAllActivity = $false
  }
  else {
    $matchedAllActivity = $true
  }
  $app | Add-Member -MemberType NoteProperty -Name "MatchedAllActivity" -Value $matchedAllActivity -Force

  # Display summary
  Write-Host "  Matched Activities: $($optimalSet.MatchedActivities)/$($optimalSet.TotalActivities)" -ForegroundColor Green
  Write-Host "  Optimal Permissions: $($optimalSet.OptimalPermissions.Count)" -ForegroundColor Green
  Write-Host "  Current Permissions: $($currentPermissions.Count)" -ForegroundColor Yellow
  Write-Host "  Excess Permissions: $($excessPermissions.Count)" -ForegroundColor $(if ($excessPermissions.Count -gt 0) { "Red" }else { "Green" })
}


New-PermissionAnalysisReport -AppData $lightweightGroups[10..30] -OutputPath ".\report.html"