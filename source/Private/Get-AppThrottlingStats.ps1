function Get-AppThrottlingStats {
    <#
.SYNOPSIS
    Retrieves throttling statistics for applications from Azure Log Analytics.

.DESCRIPTION
    This function queries Azure Log Analytics to retrieve comprehensive Microsoft Graph API throttling
    statistics for service principals. It analyzes request patterns, error rates, and throttling severity
    over a specified time period.

    The function calculates various metrics including:
    - Total request counts and success rates
    - HTTP 429 (Too Many Requests) error counts
    - Client errors (4xx) and server errors (5xx)
    - Throttle rates (percentage of requests throttled)
    - Overall error and success rates
    - Throttling severity classification (0-4 scale)
    - First and last occurrence timestamps

    Severity levels are automatically calculated based on throttle rates:
    - 0 (Normal): No throttling errors detected
    - 1 (Minimal): Throttle rate < 1%
    - 2 (Low): Throttle rate 1-5%
    - 3 (Warning): Throttle rate 5-10%
    - 4 (Critical): Throttle rate >= 10%

    The function can analyze all applications in the tenant or focus on a specific service principal.

.PARAMETER WorkspaceId
    The Azure Log Analytics workspace ID (GUID) where Microsoft Graph activity logs are stored.
    This workspace must contain the MicrosoftGraphActivityLogs table.

    Example: "12345678-1234-1234-1234-123456789012"

.PARAMETER Days
    The number of days of historical data to analyze, counting back from the current date.
    Default: 30 days

    Recommended values:
    - 7 days: Recent throttling patterns
    - 30 days: Standard monthly analysis
    - 90 days: Long-term trend analysis

.PARAMETER ServicePrincipalId
    Optional parameter to filter results for a specific service principal.
    If not provided, retrieves throttling statistics for all applications.

    Example: "87654321-4321-4321-4321-210987654321"

.OUTPUTS
    Array
    Returns an array of PSCustomObjects with the following properties:
    - ServicePrincipalId: The service principal ID (object ID)
    - AppId: The application (client) ID
    - TotalRequests: Total number of API requests made
    - SuccessfulRequests: Count of successful requests (HTTP 200)
    - Total429Errors: Count of throttling errors (HTTP 429)
    - TotalClientErrors: Count of all client errors (HTTP 4xx)
    - TotalServerErrors: Count of all server errors (HTTP 5xx)
    - ThrottleRate: Percentage of requests that were throttled
    - ErrorRate: Percentage of all failed requests
    - SuccessRate: Percentage of successful requests
    - ThrottlingSeverity: Numeric severity level (0-4)
    - ThrottlingStatus: Human-readable status (Normal, Minimal, Low, Warning, Critical)
    - FirstOccurrence: Timestamp of first request in the period
    - LastOccurrence: Timestamp of last request in the period

    Returns an empty array if no data is found or if the query fails.

.EXAMPLE
    $stats = Get-AppThrottlingStats -WorkspaceId "12345-workspace-id" -Days 30
    $stats | Where-Object { $_.ThrottlingSeverity -ge 3 } | Format-Table ServicePrincipalId, ThrottlingStatus, ThrottleRate

    Retrieves 30 days of throttling data for all applications and displays those with Warning or Critical severity.

.EXAMPLE
    $singleAppStats = Get-AppThrottlingStats -WorkspaceId $workspaceId -Days 7 -ServicePrincipalId "app-sp-id"

    if ($singleAppStats -and $singleAppStats.Total429Errors -gt 0) {
        Write-Warning "Application has $($singleAppStats.Total429Errors) throttling errors (Rate: $($singleAppStats.ThrottleRate)%)"
    }

    Retrieves throttling data for a specific application and checks for issues.

.EXAMPLE
    $allStats = Get-AppThrottlingStats -WorkspaceId $workspaceId -Days 90 -Verbose
    $topThrottled = $allStats | Sort-Object Total429Errors -Descending | Select-Object -First 10
    $topThrottled | Export-Csv -Path "top-throttled-apps.csv" -NoTypeInformation

    Analyzes 90 days of data, identifies the 10 most throttled applications, and exports to CSV.

.EXAMPLE
    $stats = Get-AppThrottlingStats -WorkspaceId $workspaceId -Days 30
    $summary = $stats | Group-Object ThrottlingStatus | Select-Object Name, Count
    $summary | Format-Table -AutoSize

    Generates a summary showing how many applications fall into each throttling severity category.

.NOTES
    Prerequisites:
    - Azure Log Analytics workspace with MicrosoftGraphActivityLogs enabled
    - Appropriate permissions to query the workspace via Invoke-EntraRequest
    - EntraService module or equivalent for Log Analytics queries

    Query Details:
    - Filters out entries without ServicePrincipalId
    - Groups results by ServicePrincipalId and AppId
    - Supports optional filtering to a specific service principal
    - Maximum 10,000 rows returned (maxRows parameter)
    - Truncation limit set to 64MB (truncationMaxSize parameter)

    Performance Considerations:
    - Query is optimized with KQL summarization
    - Results are grouped at the query level for efficiency
    - Supports large-scale tenant analysis

    Error Handling:
    - Returns empty array if query fails or no data is found
    - Uses Write-Warning for query failures
    - Uses Write-Debug for detailed processing information

    This function uses Invoke-EntraRequest to communicate with Log Analytics and requires
    proper authentication and authorization to the workspace.
#>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,

        [Parameter(Mandatory = $false)]
        [int]$Days = 30,

        [Parameter(Mandatory = $false)]
        [string]$ServicePrincipalId
    )

    Write-Debug "Querying throttling statistics for last $Days days..."

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
        $response = Invoke-EntraRequest -Service "LogAnalytics" -Method POST `
            -Path "/v1/workspaces/$WorkspaceId/query?timespan=P$($Days)D" `
            -Body ($body | ConvertTo-Json -Depth 10)

        if ($response.tables -and $response.tables.Count -gt 0 -and $response.tables[0].rows) {
            $columns = $response.tables[0].columns.name
            $results = @()

            foreach ($row in $response.tables[0].rows) {
                $obj = [PSCustomObject]@{}
                for ($i = 0; $i -lt $columns.Count; $i++) {
                    $obj | Add-Member -MemberType NoteProperty -Name $columns[$i] -Value $row[$i]
                }
                $results += $obj
            }

            Write-Debug "Retrieved throttling stats for $($results.Count) service principals."
            return $results
        }
        else {
            Write-Debug "No throttling data found."
            return @()
        }
    }
    catch {
        Write-Warning "Failed to query throttling statistics. Error: $_"
        Write-Debug $_.Exception.Message
        return @()
    }
}
