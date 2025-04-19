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