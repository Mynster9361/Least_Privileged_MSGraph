<#
.SYNOPSIS
    Get Microsoft Graph Role Assignments
.DESCRIPTION
    This script retrieves role assignments from Microsoft Graph API and formats them for easier analysis.
.PARAMETER OutputFile
    Path to save the formatted role assignments. If not specified, outputs to console.
.PARAMETER Filter
    Optional filter to apply to the role assignments.
.EXAMPLE
    .\Get-MSGraphRoleAssignments.ps1 -OutputFile "roleAssignments.txt" -Filter "roleDefinitionId eq '12345'"
#>

function Get-GraphRoleAssignments {

    $appRoleAssignments = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'" -ExpandProperty AppRoleAssignedTo -All
    $appRoles = $appRoleAssignments.AppRoles

    # Group by PrincipalId
    $groupedAssignments = $appRoleAssignments.AppRoleAssignedTo | Group-Object -Property PrincipalId

    $permissionMapper = Get-Content .\graph_api_permissions_map.json | ConvertFrom-Json
    $roleAssignments = @()

    foreach ($group in $groupedAssignments) {
        $principalId = $group.Name
        $firstAssignment = $group.Group | Select-Object -First 1


        # Collect all permissions for this principal
        $permissions = $group.Group | ForEach-Object {
            $currentAppRoleId = $_.AppRoleId
            $friendlyName = $appRoles | Where-Object { $_.Id -eq $currentAppRoleId } | Select-Object DisplayName, Description, Origin, Value
            [PSCustomObject]@{
                AppRoleId    = $currentAppRoleId
                FriendlyName = $friendlyName.DisplayName
                Description  = $friendlyName.Description
                Origin       = $friendlyName.Origin
                Value        = $friendlyName.Value
                Id           = $_.Id
            }
        }

        # Create a consolidated object for this principal
        $roleAssignment = [PSCustomObject]@{
            PrincipalDisplayName = $firstAssignment.PrincipalDisplayName
            PrincipalType        = $firstAssignment.PrincipalType
            PrincipalId          = $principalId
            Permissions          = $permissions
            urlPaths           = foreach ($permission in $permissions) {
                $permissionMapper | Where-Object {
                    ($_.Application_Least -contains $permission.Value) -or
                    ($_.DelegatedWork_Least -contains $permission.Value)
                } | Select-Object path, full_example_url, method, version | Sort-Object path -Unique
            }
        }
        $roleAssignments += $roleAssignment
    }
    return $roleAssignments
}

function Get-GraphPermissionUsage {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RoleAssignment,

        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,

        [Parameter(Mandatory = $true)]
        [string]$WorkspaceName,

        [int]$DaysToLookBack = 30
    )

    # Format the time range
    $startTime = (Get-Date).AddDays(-$DaysToLookBack).ToString("yyyy-MM-dd")
    $endTime = Get-Date -Format "yyyy-MM-dd"

    # Build the KQL query
    $query = @"
// Check usage for ServicePrincipalId: $($RoleAssignment.PrincipalId)
MicrosoftGraphActivityLogs
| where TimeGenerated > datetime('$startTime')
| where ServicePrincipalId == "$($RoleAssignment.PrincipalId)"
| extend ParsedUri = replace_regex(RequestUri, @'\?.*$', '')
| extend ApiPath = extract("https://graph\\.microsoft\\.com/(v[\\d\\.]+|beta)/([^?]+)", 2, ParsedUri)
| extend ApiVersion = extract("https://graph\\.microsoft\\.com/(v[\\d\\.]+|beta)", 1, ParsedUri)
| extend NormalizedPath = ApiPath
| extend NormalizedPath = replace_regex(NormalizedPath, @'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})', '{id}')
| extend NormalizedPath = replace_regex(NormalizedPath, @'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})', '{userPrincipalName}')
| extend NormalizedPath = replace_regex(NormalizedPath, @'users/[^/]+', 'users/{id}')
| extend NormalizedPath = replace_regex(NormalizedPath, @'groups/[^/]+', 'groups/{id}')
| summarize
    RequestCount = count(),
    LastAccess = max(TimeGenerated),
    StatusCodes = make_set(ResponseStatusCode),
    Versions = make_set(ApiVersion)
    by RequestMethod, NormalizedPath
| order by RequestCount desc
"@

    # Run the query
    #$results = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceId -Query $query -ErrorAction Stop
    $job = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceId -Query $query -Timespan $timespan -AsJob
	$job | Wait-Job
	$results = $job | Receive-Job

    # Process results
    if ($results -and $results.Results) {
        $usageData = $results.Results

        # Add a flag to indicate if the path is included in allowed permissions
        $usageData | ForEach-Object {
            $currentPath = $_.NormalizedPath
            $currentMethod = $_.RequestMethod
            $permissionMatch = $RoleAssignment.UrlPaths | Where-Object {
                $path = $_.path -replace '{[^}]+}', '{id}'  # Normalize comparison path
                $path -eq "/$currentPath" -or $path -eq $currentPath -or $currentPath.StartsWith($path)
            }

            $_ | Add-Member -MemberType NoteProperty -Name 'IsAuthorized' -Value ($null -ne $permissionMatch)
        }

        # Return the processed results
        return $usageData
    }

    return $null
}

# Connect to Log Analytics
#Connect-MgGraph
#Connect-AzAccount -TenantId "98db9fb9-f52b-4e63-83d9-795ccd2dfcca" -SubscriptionId "b51db61a-01f4-415d-94c9-1d7aec8b7e84" # Replace with your actual tenant and subscription IDs
$permissionMapper = Get-Content .\graph_api_permissions_map.json | ConvertFrom-Json
$roleAssignments = Get-GraphRoleAssignments

foreach ($roleAssignment in $roleAssignments) {
    $urlPaths = @()
    foreach ($permission in $roleAssignment.Permissions) {
        $urlPaths += $permissionMapper | Where-Object {
            ($_.Application_Least -contains $permission.Value) -or
            ($_.DelegatedWork_Least -contains $permission.Value)
        } | Select-Object path, full_example_url, method, version | Sort-Object path -Unique
    }
    $roleAssignment | Add-Member -MemberType NoteProperty -Name UrlPaths -Value $urlPaths

    # Optional: Get usage data from Log Analytics
    # Uncomment this section when you're ready to run the Log Analytics query
    $workspaceId = ""  # Replace with your actual workspace ID
    $workspaceName = ""  # Replace with your actual workspace name
    $usageData = Get-GraphPermissionUsage -RoleAssignment $roleAssignment -WorkspaceId $workspaceId -WorkspaceName $workspaceName -DaysToLookBack 1
    $roleAssignment | Add-Member -MemberType NoteProperty -Name UsageData -Value $usageData
}

# Display results
$usage = $roleAssignments | ForEach-Object {
    Write-Host "`n==============================================" -ForegroundColor Cyan
    Write-Host "Application: $($_.PrincipalDisplayName)" -ForegroundColor Green
    Write-Host "ID: $($_.PrincipalId)" -ForegroundColor Yellow
    Write-Host "Permissions: $($_.Permissions.Value -join ', ')" -ForegroundColor White

    if ($_.UsageData) {
        Write-Host "`nAPI Usage (Past 30 Days):" -ForegroundColor Magenta
        $_.UsageData #| Format-Table -Property RequestMethod, NormalizedPath, RequestCount

        # Calculate unused permissions
        $usedPaths = $_.UsageData | Where-Object { $_.IsAuthorized -eq $true } | ForEach-Object { $_.NormalizedPath }
        $unusedPaths = $_.UrlPaths | Where-Object {
            $normalizedPath = $_.path -replace '{[^}]+}', '{id}'
            $normalizedPath = $normalizedPath.TrimStart('/')
            $usedPaths -notcontains $normalizedPath
        }

        if ($unusedPaths) {
            Write-Host "`nUnused Permission Paths:" -ForegroundColor Red
            $unusedPaths | ForEach-Object { Write-Host "  $($_.method) $($_.path)" }
        }
    }
    #Pause
}
