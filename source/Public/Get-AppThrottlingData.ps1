function Get-AppThrottlingData {
    <#
.SYNOPSIS
    Enriches application data with throttling statistics from Azure Log Analytics.

.DESCRIPTION
    This function queries Azure Log Analytics to retrieve Microsoft Graph API throttling statistics
    for each application over a specified time period. It gets comprehensive throttling metrics as
    a new property to each application object, enabling analysis of API rate limiting impacts.

    The function processes all applications efficiently by:
    1. Fetching all throttling statistics in a single batch query
    2. Creating an indexed lookup table for fast matching
    3. Matching applications to their statistics using ServicePrincipalId
    4. Getting zeroed statistics for applications without activity

    Throttling metrics include:
    - Total requests and success/error counts
    - 429 (Too Many Requests) error counts and throttle rates
    - Overall error and success rates
    - Throttling severity classification (0-4 scale)
    - First and last occurrence timestamps
    - Human-readable throttling status

    This data is critical for identifying applications experiencing API rate limiting issues
    and understanding their impact on application performance.

.PARAMETER AppData
    An array of application objects to enrich with throttling data. Each object should contain:
    - PrincipalId: The service principal ID of the application (used for matching)
    - PrincipalName: The application display name (for logging/progress)

    This parameter accepts pipeline input, allowing you to pipe application objects directly
    into the function.

.PARAMETER WorkspaceId
    The Azure Log Analytics workspace ID (GUID) where Microsoft Graph API activity logs are stored.
    This workspace must contain MicrosoftGraphActivityLogs table with throttling information.

    Example: "12345678-1234-1234-1234-123456789012"

.PARAMETER Days
    The number of days of historical throttling data to retrieve, counting back from the current date.
    Default: 30 days

    Recommended values:
    - 7 days: Recent throttling analysis
    - 30 days: Standard monthly review
    - 90 days: Comprehensive quarterly analysis

.OUTPUTS
    Array
    Returns the input application objects enriched with a "ThrottlingStats" property containing:
    - TotalRequests: Total API requests made
    - SuccessfulRequests: Requests that succeeded (2xx responses)
    - Total429Errors: Number of throttling errors
    - TotalClientErrors: All 4xx errors (including 429)
    - TotalServerErrors: All 5xx errors
    - ThrottleRate: Percentage of requests that were throttled
    - ErrorRate: Percentage of all failed requests
    - SuccessRate: Percentage of successful requests
    - ThrottlingSeverity: Numeric severity (0=Normal, 1=Minimal, 2=Low, 3=Warning, 4=Critical)
    - ThrottlingStatus: Human-readable status description
    - FirstOccurrence: Timestamp of first request in period
    - LastOccurrence: Timestamp of last request in period

    Applications without activity receive zeroed statistics with "No Activity" status.

.EXAMPLE
    $apps = Get-MgServicePrincipal -Filter "appId eq '00000000-0000-0000-0000-000000000000'"
    $enrichedApps = $apps | Get-AppThrottlingData -WorkspaceId "12345678-abcd-efgh-ijkl-123456789012"

    Retrieves throttling statistics for a specific application over the default 30-day period.

.EXAMPLE
    $allApps = Get-MgServicePrincipal -All
    $appsWithThrottling = $allApps | Get-AppThrottlingData -WorkspaceId $workspaceId -Days 90
    $criticalApps = $appsWithThrottling | Where-Object { $_.ThrottlingStats.ThrottlingSeverity -ge 3 }

    Analyzes 90 days of data and identifies applications with Warning or Critical throttling severity.

.EXAMPLE
    $apps | Get-AppThrottlingData -WorkspaceId $workspaceId -Days 7 -Verbose |
        Where-Object { $_.ThrottlingStats.Total429Errors -gt 100 } |
        Select-Object PrincipalName, @{N='429 Errors';E={$_.ThrottlingStats.Total429Errors}},
                      @{N='Throttle Rate';E={$_.ThrottlingStats.ThrottleRate}}

    Finds applications with more than 100 throttling errors in the last 7 days and displays key metrics.

.EXAMPLE
    $results = $apps | Get-AppThrottlingData -WorkspaceId $workspaceId -Days 30
    $results | Where-Object { $_.ThrottlingStats.ThrottlingStatus -ne 'No Activity' } |
        Export-Csv -Path "throttling-report.csv" -NoTypeInformation

    Exports throttling data for all active applications to a CSV file.

.NOTES
    Prerequisites:
    - Azure Log Analytics workspace with MicrosoftGraphActivityLogs enabled
    - Appropriate permissions to query the Log Analytics workspace
    - Get-AppThrottlingStats function must be available

    Performance Considerations:
    - Uses bulk query approach for better performance
    - Processes all applications in a single Log Analytics query
    - Creates indexed lookup table for O(1) matching
    - Progress bar displays processing status

    Throttling Severity Scale:
    - 0 (Normal): No throttling or very minimal (< 1%)
    - 1 (Minimal): Low throttling (1-5%)
    - 2 (Low): Noticeable throttling (5-10%)
    - 3 (Warning): Significant throttling (10-25%)
    - 4 (Critical): Severe throttling (> 25%)

    Matching Logic:
    - Uses ServicePrincipalId (case-insensitive) for matching
    - Applications without matches receive zeroed statistics
    - Logs verbose information about match success/failure

    This function uses Write-Debug for detailed processing information, Write-Verbose for
    match status updates, and Write-Progress for visual feedback.
#>
    [CmdletBinding()]
    [OutputType([System.String])]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [array]$AppData,

        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,

        [Parameter(Mandatory = $false)]
        [int]$Days = 30
    )

    begin {
        Write-Verbose "Fetching throttling statistics for all applications..."
        $throttlingStats = Get-AppThrottlingStats -WorkspaceId $WorkspaceId -Days $Days

        Write-Debug "Retrieved $($throttlingStats.Count) throttling stat records from Log Analytics"

        if ($throttlingStats.Count -gt 0) {
            Write-Verbose "Sample ServicePrincipalIds from Log Analytics:"
            $throttlingStats | Select-Object -First 3 | ForEach-Object {
                Write-Verbose "  - ServicePrincipalId: $($_.ServicePrincipalId), AppId: $($_.AppId), Requests: $($_.TotalRequests)"
            }
        }

        # Create lookup by ServicePrincipalId (case-insensitive)
        $throttlingBySpId = @{}

        foreach ($stat in $throttlingStats) {
            if ($stat.ServicePrincipalId) {
                # Normalize to lowercase for case-insensitive matching
                $normalizedSpId = $stat.ServicePrincipalId.ToString().ToLower()
                $throttlingBySpId[$normalizedSpId] = $stat
                Write-Debug "Indexed throttling data for ServicePrincipalId: $normalizedSpId"
            }
        }

        Write-Verbose "Created lookup table with $($throttlingBySpId.Count) entries"

        $allProcessedApps = [System.Collections.ArrayList]::new()
        $currentIndex = 0
    }

    process {
        foreach ($app in $AppData) {
            $currentIndex++
            $spId = $app.PrincipalId

            # Update progress bar
            Write-Progress -Activity "Getting Throttling Statistics" `
                -Status "Processing $currentIndex applications" `
                -CurrentOperation $app.PrincipalName `
                -PercentComplete 0

            # Try to find throttling data using ServicePrincipalId (case-insensitive)
            $throttlingData = $null
            if ($spId) {
                $normalizedLookupSpId = $spId.ToString().ToLower()

                if ($throttlingBySpId.ContainsKey($normalizedLookupSpId)) {
                    $throttlingData = $throttlingBySpId[$normalizedLookupSpId]
                    Write-Verbose "✓ Matched throttling data for $($app.PrincipalName) (ServicePrincipalId: $spId)"
                }
                else {
                    Write-Verbose "✗ No throttling data found for $($app.PrincipalName) (ServicePrincipalId: $spId)"

                    # Debug: Show what ServicePrincipalIds ARE in the lookup
                    if ($throttlingBySpId.Count -gt 0 -and $currentIndex -eq 1) {
                        Write-Verbose "Available ServicePrincipalIds in lookup (first 5):"
                        $throttlingBySpId.Keys | Select-Object -First 5 | ForEach-Object {
                            Write-Verbose "  - $_"
                        }
                    }
                }
            }

            # Always get ThrottlingStats - either real data or zeroed out values
            if ($throttlingData) {
                $app | Add-Member -MemberType NoteProperty -Name "ThrottlingStats" -Value ([PSCustomObject]@{
                        TotalRequests      = $throttlingData.TotalRequests
                        SuccessfulRequests = $throttlingData.SuccessfulRequests
                        Total429Errors     = $throttlingData.Total429Errors
                        TotalClientErrors  = $throttlingData.TotalClientErrors
                        TotalServerErrors  = $throttlingData.TotalServerErrors
                        ThrottleRate       = $throttlingData.ThrottleRate
                        ErrorRate          = $throttlingData.ErrorRate
                        SuccessRate        = $throttlingData.SuccessRate
                        ThrottlingSeverity = $throttlingData.ThrottlingSeverity
                        ThrottlingStatus   = $throttlingData.ThrottlingStatus
                        FirstOccurrence    = $throttlingData.FirstOccurrence
                        LastOccurrence     = $throttlingData.LastOccurrence
                    }) -Force

                Write-Debug "Got throttling stats for $($app.PrincipalName): Severity=$($throttlingData.ThrottlingSeverity), Status=$($throttlingData.ThrottlingStatus)"
            }
            else {
                # No activity found - get zeroed stats
                $app | Add-Member -MemberType NoteProperty -Name "ThrottlingStats" -Value ([PSCustomObject]@{
                        TotalRequests      = 0
                        SuccessfulRequests = 0
                        Total429Errors     = 0
                        TotalClientErrors  = 0
                        TotalServerErrors  = 0
                        ThrottleRate       = 0
                        ErrorRate          = 0
                        SuccessRate        = 0
                        ThrottlingSeverity = 0
                        ThrottlingStatus   = "No Activity"
                        FirstOccurrence    = $null
                        LastOccurrence     = $null
                    }) -Force

                Write-Debug "No throttling data found for $($app.PrincipalName) (ServicePrincipalId: $spId) - got zero stats"
            }

            [void]$allProcessedApps.Add($app)
        }
    }

    end {
        Write-Progress -Activity "Getting Throttling Statistics" -Completed

        $matchedCount = ($allProcessedApps | Where-Object {
                $_.ThrottlingStats -and $_.ThrottlingStats.TotalRequests -gt 0
            }).Count

        Write-Debug "Successfully processed $($allProcessedApps.Count) applications."
        Write-Debug "  - Found throttling data for: $matchedCount applications"
        Write-Debug "  - No activity for: $($allProcessedApps.Count - $matchedCount) applications"

        return $allProcessedApps
    }
}
