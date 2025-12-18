function Get-AppThrottlingStat {
    <#
.SYNOPSIS
    Internal function to retrieve Microsoft Graph API throttling statistics from Log Analytics.

.DESCRIPTION
    This private function queries Azure Log Analytics to retrieve throttling statistics for service
    principals. It's used internally by Get-AppThrottlingData and Get-PermissionAnalysis to analyze
    application health and API consumption patterns.

    The function returns detailed metrics including:
    - Request counts (total, successful, errors)
    - HTTP 429 throttling error counts
    - Calculated rates (throttle, error, success)
    - Severity classification (0-4)
    - Time range of analyzed data

    Throttling Severity Levels:
    - 0: Normal (no throttling)
    - 1: Minimal (< 1%)
    - 2: Low (1-5%)
    - 3: Warning (5-10%)
    - 4: Critical (>= 10%)

.PARAMETER WorkspaceId
    Log Analytics workspace ID (GUID) containing MicrosoftGraphActivityLogs table.

.PARAMETER Days
    Number of days of historical data to analyze. Default: 30

.PARAMETER ServicePrincipalId
    Optional. Filter results for a specific service principal object ID.

.OUTPUTS
    System.Object[]
    Array of objects with properties: ServicePrincipalId, AppId, TotalRequests,
    SuccessfulRequests, Total429Errors, TotalClientErrors, TotalServerErrors,
    ThrottleRate, ErrorRate, SuccessRate, ThrottlingSeverity, ThrottlingStatus,
    FirstOccurrence, LastOccurrence

    Returns empty array (@()) if no data found or query fails.

.EXAMPLE
    $stats = Get-AppThrottlingStat -WorkspaceId $workspaceId -Days 30
    $criticalApps = $stats | Where-Object { $_.ThrottlingSeverity -ge 3 }

.EXAMPLE
    # Used internally by Get-AppThrottlingData
    $throttlingData = Get-AppThrottlingStat -WorkspaceId $config.WorkspaceId -Days $Days -ServicePrincipalId $spId

.NOTES
    This is a private module function not exported to users.

    Requirements:
    - Invoke-EntraRequest must be available
    - Appropriate Log Analytics permissions
    - MicrosoftGraphActivityLogs table must exist and contain data

    Query uses KQL summarization for efficiency and returns max 10,000 rows.
    Uses exponential backoff logic handled by Invoke-EntraRequest.
#>
    [CmdletBinding(DefaultParameterSetName = 'ByWorkspaceId')]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByWorkspaceId')]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspaceId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByWorkspaceDetails')]
        [ValidateNotNullOrEmpty()]
        [string]$subId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByWorkspaceDetails')]
        [ValidateNotNullOrEmpty()]
        [string]$rgName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByWorkspaceDetails')]
        [ValidateNotNullOrEmpty()]
        [string]$workspaceName,

        [Parameter(Mandatory = $false)]
        [int]$Days = 30,

        [Parameter(Mandatory = $false)]
        [string]$ServicePrincipalId
    )

    Write-PSFMessage -Level Debug -Message  "Querying throttling statistics for last $Days days..."

    $spIdFilter = if ($ServicePrincipalId) {
        "| where ServicePrincipalId == '$ServicePrincipalId'"
    }
    else {
        ""
    }

    # Query groups by ServicePrincipalId instead of AppId
    $query = @"
MicrosoftGraphActivityLogs
| where ServicePrincipalId != ""
$spIdFilter
| summarize
    TotalRequests = count(),
    Total429Errors = countif(ResponseStatusCode == 429),
    SuccessfulRequests = countif(ResponseStatusCode == 200),
    TotalClientErrors = countif(ResponseStatusCode >= 400 and ResponseStatusCode < 500),
    TotalServerErrors = countif(ResponseStatusCode >= 500),
    FirstOccurrence = min(TimeGenerated),
    LastOccurrence = max(TimeGenerated)
    by ServicePrincipalId, AppId
| extend
    ThrottleRate = round((Total429Errors * 100.0) / TotalRequests, 2),
    ErrorRate = round(((TotalClientErrors + TotalServerErrors) * 100.0) / TotalRequests, 2),
    SuccessRate = round((SuccessfulRequests * 100.0) / TotalRequests, 2)
| extend
    ThrottlingSeverity = case(
        Total429Errors == long(0), 0,
        ThrottleRate >= 10.0, 4,
        ThrottleRate >= 5.0, 3,
        ThrottleRate >= 1.0, 2,
        1
    ),
    ThrottlingStatus = case(
        Total429Errors == long(0), "Normal",
        ThrottleRate >= 10.0, "Critical",
        ThrottleRate >= 5.0, "Warning",
        ThrottleRate >= 1.0, "Low",
        "Minimal"
    )
| project
    ServicePrincipalId,
    AppId,
    TotalRequests,
    SuccessfulRequests,
    Total429Errors,
    TotalClientErrors,
    TotalServerErrors,
    ThrottleRate,
    ErrorRate,
    SuccessRate,
    ThrottlingSeverity,
    ThrottlingStatus,
    FirstOccurrence,
    LastOccurrence
"@

    $body = @{
        query            = $query
        options          = @{
            truncationMaxSize = 67108864
        }
        maxRows          = 10000
        workspaceFilters = @{
            regions = @()
        }
    }

    try {
        $splatEntraRequest = @{
            Service = "LogAnalytics"
            Method  = "POST"
            Query   = @{ timespan = "P$($Days)D" }
            Body    = $body
        }
        if ($PSCmdlet.ParameterSetName -eq 'ByWorkspaceDetails') {
            $splatEntraRequest.Add("Path", "/v1/subscriptions/$subId/resourceGroups/$rgName/providers/Microsoft.OperationalInsights/workspaces/$workspaceName/query")
        }
        else {
            $splatEntraRequest.Add("Path", "/v1/workspaces/$WorkspaceId/query")
        }

        $response = Invoke-EntraRequest @splatEntraRequest
    }
    catch {
        Write-Warning "Failed to query throttling statistics. Error: $_"
        Write-PSFMessage -Level Debug -Message  $_.Exception.Message
        return
    }

    if ($response.tables -and $response.tables.Count -gt 0 -and $response.tables[0].rows) {
        $columns = $response.tables[0].columns.name
        foreach ($row in $response.tables[0].rows) {
            $obj = [PSCustomObject]@{}
            for ($i = 0; $i -lt $columns.Count; $i++) {
                $obj | Add-Member -MemberType NoteProperty -Name $columns[$i] -Value $row[$i]
            }
            [PSCustomObject]$obj
        }

        Write-PSFMessage -Level Debug -Message  "Retrieved throttling stats for $(@($response.tables[0].rows).Count) service principals."
        return
    }
    else {
        Write-PSFMessage -Level Debug -Message  "No throttling data found."
        return
    }
}
