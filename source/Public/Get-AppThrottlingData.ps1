function Get-AppThrottlingData {
    <#
.SYNOPSIS
    Enriches application data with throttling statistics from Azure Log Analytics.

.DESCRIPTION
    This function queries Azure Log Analytics to retrieve Microsoft Graph API throttling statistics
    for each application over a specified time period. It adds comprehensive throttling metrics as
    a new property to each application object, enabling analysis of API rate limiting impacts.

    The function processes all applications efficiently by:
    1. Fetching all throttling statistics in a single batch query
    2. Creating an indexed lookup table for fast matching (O(1) complexity)
    3. Matching applications to their statistics using ServicePrincipalId
    4. Adding zeroed statistics for applications without activity
    5. Providing progress feedback during processing

    Throttling metrics include:
    - **Request Counts**: Total requests, successful requests, errors by type
    - **Rate Calculations**: Throttle rate, error rate, success rate (percentages)
    - **Severity Classification**: Automatic 0-4 scale based on throttle rate
    - **Status Descriptions**: Human-readable severity labels (Normal, Warning, Critical, etc.)
    - **Time Range**: First and last occurrence timestamps for analyzed period

    Severity Classification:
    - **0 (Normal)**: No throttling detected or < 1% throttle rate
    - **1 (Minimal)**: 1-5% throttle rate - occasional throttling
    - **2 (Low)**: 5-10% throttle rate - regular throttling, should be monitored
    - **3 (Warning)**: 10-25% throttle rate - significant throttling, optimization recommended
    - **4 (Critical)**: > 25% throttle rate - severe throttling, immediate action required

    This data is critical for:
    - Identifying applications experiencing API rate limiting issues
    - Understanding performance impact on users
    - Prioritizing optimization efforts
    - Capacity planning for Graph API usage
    - Troubleshooting application performance problems
    - Monitoring application health over time

    Use Cases:
    - **Performance Monitoring**: Track API throttling trends across applications
    - **Incident Investigation**: Identify throttled apps during performance issues
    - **Optimization Planning**: Prioritize which apps need retry logic/batching
    - **Health Dashboards**: Create executive reports on API health
    - **SLA Monitoring**: Ensure applications meet performance requirements
    - **Capacity Planning**: Understand API consumption patterns

.PARAMETER AppData
    An array of application objects to enrich with throttling data. This parameter accepts
    pipeline input for efficient processing.

    Required Properties:
    - **PrincipalId** (String): Service principal object ID (used for matching statistics)
    - **PrincipalName** (String): Application display name (used for logging and progress)

    Optional Properties:
    - Any other properties are preserved and passed through
    - Commonly includes: AppId, Tags, AppRoles, Activity, etc.

    Example application object:
    @{
        PrincipalId = "12345678-1234-1234-1234-123456789012"
        PrincipalName = "HR Application"
        AppId = "87654321-4321-4321-4321-210987654321"
    }

.PARAMETER WorkspaceId
    The Azure Log Analytics workspace ID (GUID) where Microsoft Graph activity logs are stored.
    This workspace must contain the MicrosoftGraphActivityLogs table with diagnostic logging enabled.
    Used with the 'ByWorkspaceId' parameter set (default).
    Mutually exclusive with subId, rgName, and workspaceName parameters.

.PARAMETER subId
    Azure subscription ID where the Log Analytics workspace is located.
    Used with the 'ByWorkspaceDetails' parameter set.
    Required when using user_impersonation token scope.

.PARAMETER rgName
    Resource group name where the Log Analytics workspace is located.
    Used with the 'ByWorkspaceDetails' parameter set.
    Required when using user_impersonation token scope.

.PARAMETER workspaceName
    Log Analytics workspace name.
    Used with the 'ByWorkspaceDetails' parameter set.
    Required when using user_impersonation token scope.

.PARAMETER Days
    The number of days of historical throttling data to retrieve, counting back from the current date.

    Default: 30 days

    Recommended values:
    - **7 days**: Recent throttling patterns and quick health checks
    - **30 days**: Standard monthly review and reporting (default)
    - **90 days**: Comprehensive quarterly analysis for trend detection

    Considerations:
    - Longer periods provide more comprehensive data
    - Balance between data completeness and query performance
    - Maximum limited by Log Analytics retention period (typically 30-730 days)

.OUTPUTS
    System.Collections.ArrayList
    Returns the input application objects enriched with a "ThrottlingStats" property.

    ThrottlingStats Property Structure (PSCustomObject):

    TotalRequests (Int64)
        Total number of Microsoft Graph API requests made during the period
        Example: 15000

    SuccessfulRequests (Int64)
        Count of successful requests (HTTP 2xx status codes)
        Example: 14250

    Total429Errors (Int64)
        Count of throttling errors (HTTP 429 "Too Many Requests")
        Example: 150

    TotalClientErrors (Int64)
        Count of all client errors (HTTP 4xx status codes, including 429)
        Example: 500

    TotalServerErrors (Int64)
        Count of all server errors (HTTP 5xx status codes)
        Example: 250

    ThrottleRate (Double)
        Percentage of requests that were throttled (429 errors / total * 100)
        Rounded to 2 decimal places
        Example: 1.00 (meaning 1%)

    ErrorRate (Double)
        Percentage of all failed requests (client + server errors / total * 100)
        Rounded to 2 decimal places
        Example: 5.00 (meaning 5%)

    SuccessRate (Double)
        Percentage of successful requests (successful / total * 100)
        Rounded to 2 decimal places
        Example: 95.00 (meaning 95%)

    ThrottlingSeverity (Int32)
        Numeric severity level based on throttle rate
        Values: 0 (Normal), 1 (Minimal), 2 (Low), 3 (Warning), 4 (Critical)

    ThrottlingStatus (String)
        Human-readable status description
        Values: "Normal", "Minimal", "Low", "Warning", "Critical", "No Activity"

    FirstOccurrence (DateTime or $null)
        Timestamp of the first API request in the analyzed period
        Example: 2025-11-01T00:00:00Z
        $null if no activity

    LastOccurrence (DateTime or $null)
        Timestamp of the last API request in the analyzed period
        Example: 2025-11-30T23:59:59Z
        $null if no activity

    Special Cases:
    - Applications without activity receive zeroed statistics with "No Activity" status
    - All numeric fields set to 0
    - FirstOccurrence and LastOccurrence are $null

.EXAMPLE
    Connect-EntraService -Service "GraphBeta"
    $apps = Get-MgServicePrincipal -Filter "appId eq '12345678-1234-1234-1234-123456789012'"
    $enrichedApps = $apps | Get-AppThrottlingData -WorkspaceId "workspace-guid"

    Description:
    Retrieves throttling statistics for a specific application over the default 30-day period.
    The returned object includes ThrottlingStats property with all metrics.

.EXAMPLE
    $allApps = Get-MgServicePrincipal -All
    $appsWithThrottling = $allApps | Get-AppThrottlingData -WorkspaceId $workspaceId -Days 90 -Verbose
    $criticalApps = $appsWithThrottling | Where-Object {
        $_.ThrottlingStats.ThrottlingSeverity -ge 3
    }

    "`nApplications Requiring Immediate Attention:"
    $criticalApps | Select-Object PrincipalName,
        @{N='Throttle Rate';E={"{0:N2}%" -f $_.ThrottlingStats.ThrottleRate}},
        @{N='429 Errors';E={$_.ThrottlingStats.Total429Errors}},
        @{N='Status';E={$_.ThrottlingStats.ThrottlingStatus}} |
        Format-Table -AutoSize

    Description:
    Analyzes 90 days of data for all applications and identifies those with Warning or Critical
    throttling severity, displaying key metrics for prioritization.

.EXAMPLE
    $apps | Get-AppThrottlingData -WorkspaceId $workspaceId -Days 7 -Verbose |
        Where-Object { $_.ThrottlingStats.Total429Errors -gt 100 } |
        Select-Object PrincipalName,
            @{N='429 Errors';E={$_.ThrottlingStats.Total429Errors}},
            @{N='Throttle Rate';E={$_.ThrottlingStats.ThrottleRate}},
            @{N='Total Requests';E={$_.ThrottlingStats.TotalRequests}} |
        Sort-Object {$_.ThrottlingStats.Total429Errors} -Descending |
        Export-Csv -Path "high-throttling-apps.csv" -NoTypeInformation

    Description:
    Finds applications with more than 100 throttling errors in the last 7 days,
    sorts by error count, and exports to CSV for detailed investigation.


.NOTES
    Prerequisites:
    - Azure Log Analytics workspace with MicrosoftGraphActivityLogs table enabled
    - Microsoft Graph diagnostic settings configured to send logs to workspace
    - Appropriate permissions to query Log Analytics via Invoke-EntraRequest
    - Get-AppThrottlingStat function must be available (private function dependency)
    - PowerShell 5.1 or later

    Log Analytics Configuration:
    To enable Microsoft Graph activity logging:
    1. Navigate to Azure AD > Diagnostic settings
    2. Add diagnostic setting
    3. Select "MicrosoftGraphActivityLogs" log category
    4. Send to Log Analytics workspace
    5. Wait 10-15 minutes for initial data to appear

    Performance Characteristics:
    - **Bulk Query Approach**: Single Log Analytics query for all applications
    - **Lookup Table**: O(1) complexity for matching applications to statistics
    - **Memory Efficient**: Indexed lookup minimizes memory overhead
    - **Processing Time**: ~5-30 seconds for typical tenants (100-1000 apps)
    - **Scalability**: Handles thousands of applications efficiently

    Matching Logic:
    - Uses ServicePrincipalId (object ID) for matching
    - Case-insensitive matching for reliability
    - Applications without matches receive zeroed statistics
    - Verbose logging shows match success/failure for troubleshooting

    Throttling Severity Thresholds:
    The severity classification uses the following throttle rate thresholds:
    - **0 (Normal)**: < 1% throttle rate
    - **1 (Minimal)**: 1-5% throttle rate
    - **2 (Low)**: 5-10% throttle rate
    - **3 (Warning)**: 10-25% throttle rate
    - **4 (Critical)**: >= 25% throttle rate

    Progress Tracking:
    - Progress bar displays during processing
    - Shows application count and current operation
    - Automatically completes when finished
    - Use -Verbose for detailed match status

    Logging Levels:
    - **Write-PSFMessage -Level Debug -Message <message>**: Detailed per-app processing and matching logic
    - **Write-PSFMessage -Level Verbose -Message <message>**: Match results, sample data, and lookup table size
    - **Write-Progress**: Visual progress bar for user feedback
    - **Standard Output**: Final application objects with ThrottlingStats

    Error Handling:
    - Individual query failures handled gracefully
    - Applications without data receive zeroed statistics
    - Processing continues even if some lookups fail
    - Use -Verbose to see which apps couldn't be matched

    Common Issues:

    No throttling data for any applications:
    - Verify Microsoft Graph logging is enabled in diagnostic settings
    - Check Log Analytics workspace ID is correct
    - Ensure applications have made API calls in the specified timeframe
    - Verify diagnostic logs are flowing to workspace (check MicrosoftGraphActivityLogs table)
    - Try increasing -Days parameter

    Mismatched ServicePrincipalIds:
    - Verify applications have valid PrincipalId property
    - Check if ServicePrincipalIds in logs match app registrations
    - Use -Verbose to see sample ServicePrincipalIds from both sources
    - Ensure apps are making requests (not dormant)

    Slow performance:
    - Normal for very large tenants (5000+ apps)
    - Single bulk query is already optimized
    - Network latency to Log Analytics affects performance
    - Consider running during off-peak hours

    Memory issues:
    - Bulk approach minimizes memory usage
    - Lookup table is memory-efficient (hashtable)
    - Should handle thousands of apps without issues
    - Increase PowerShell memory limits if needed

    Zero Values vs. No Activity:
    Both result in zeroed statistics, but interpretation differs:
    - **No Activity**: App hasn't made any Graph API calls (expected for dormant apps)
    - **Zero Throttling**: App is active but not being throttled (healthy state)
    - Check TotalRequests to distinguish: 0 = no activity, > 0 = active

    Best Practices:
    - Always use -Verbose for production monitoring
    - Save results periodically for trend analysis (Export-Clixml)
    - Monitor critical applications daily with automated alerting
    - Review Warning/Critical severity apps weekly
    - Archive monthly reports for compliance and capacity planning
    - Combine with Get-AppActivityData for complete analysis
    - Implement retry logic for apps with severity >= 3

    Mitigation Strategies for Throttled Applications:
    - **Exponential Backoff**: Implement retry logic with exponential delays
    - **Request Batching**: Use $batch endpoint to combine operations
    - **Caching**: Cache frequently accessed data to reduce calls
    - **Delta Queries**: Use delta links for change tracking instead of full queries
    - **Pagination**: Use proper pagination to avoid large result sets
    - **Webhooks**: Replace polling patterns with event-driven webhooks
    - **Rate Limit Headers**: Monitor Retry-After headers and throttle accordingly
    - **Request Distribution**: Spread requests over time to avoid bursts

    Related Cmdlets:
    - Get-AppThrottlingStat: Private function that fetches raw throttling data
    - Get-AppActivityData: Add API activity information to applications
    - Get-PermissionAnalysis: Complete permission and activity analysis
    - Export-PermissionAnalysisReport: Generate visual reports including throttling data

.LINK
    https://learn.microsoft.com/en-us/graph/throttling

.LINK
    https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Get-AppThrottlingData.html
#>
    [CmdletBinding(DefaultParameterSetName = 'ByWorkspaceId')]
    [OutputType([System.String])]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [array]$AppData,

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
        [int]$Days = 30
    )

    begin {
        Write-PSFMessage -Level Verbose -Message  "Fetching throttling statistics for all applications..."
        $variables = @{
            Days = $Days
        }
        # Add parameter set specific variables
        if ($PSCmdlet.ParameterSetName -eq 'ByWorkspaceId') {
            $variables['WorkspaceId'] = $WorkspaceId
        }
        else {
            $variables['subId'] = $subId
            $variables['rgName'] = $rgName
            $variables['workspaceName'] = $workspaceName
        }
        $throttlingStats = Get-AppThrottlingStat @variables

        Write-PSFMessage -Level Debug -Message  "Retrieved $($throttlingStats.Count) throttling stat records from Log Analytics"

        if ($throttlingStats.Count -gt 0) {
            Write-PSFMessage -Level Verbose -Message  "Sample ServicePrincipalIds from Log Analytics:"
            $throttlingStats | Select-Object -First 3 | ForEach-Object {
                Write-PSFMessage -Level Verbose -Message  "  - ServicePrincipalId: $($_.ServicePrincipalId), AppId: $($_.AppId), Requests: $($_.TotalRequests)"
            }
        }

        # Create lookup by ServicePrincipalId (case-insensitive)
        $throttlingBySpId = @{}

        foreach ($stat in $throttlingStats) {
            if ($stat.ServicePrincipalId) {
                # Normalize to lowercase for case-insensitive matching
                $normalizedSpId = $stat.ServicePrincipalId.ToString().ToLower()
                $throttlingBySpId[$normalizedSpId] = $stat
                Write-PSFMessage -Level Debug -Message  "Indexed throttling data for ServicePrincipalId: $normalizedSpId"
            }
        }

        Write-PSFMessage -Level Verbose -Message  "Created lookup table with $($throttlingBySpId.Count) entries"

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
                    Write-PSFMessage -Level Verbose -Message  "Matched throttling data for $($app.PrincipalName) (ServicePrincipalId: $spId)"
                }
                else {
                    Write-PSFMessage -Level Verbose -Message  "No throttling data found for $($app.PrincipalName) (ServicePrincipalId: $spId)"

                    # Debug: Show what ServicePrincipalIds ARE in the lookup
                    if ($throttlingBySpId.Count -gt 0 -and $currentIndex -eq 1) {
                        Write-PSFMessage -Level Verbose -Message  "Available ServicePrincipalIds in lookup (first 5):"
                        $throttlingBySpId.Keys | Select-Object -First 5 | ForEach-Object {
                            Write-PSFMessage -Level Verbose -Message  "  - $_"
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

                Write-PSFMessage -Level Debug -Message  "Got throttling stats for $($app.PrincipalName): Severity=$($throttlingData.ThrottlingSeverity), Status=$($throttlingData.ThrottlingStatus)"
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

                Write-PSFMessage -Level Debug -Message  "No throttling data found for $($app.PrincipalName) (ServicePrincipalId: $spId) - got zero stats"
            }

            [void]$allProcessedApps.Add($app)
        }
    }

    end {
        Write-Progress -Activity "Getting Throttling Statistics" -Completed

        $matchedCount = ($allProcessedApps | Where-Object {
                $_.ThrottlingStats -and $_.ThrottlingStats.TotalRequests -gt 0
            }).Count

        Write-PSFMessage -Level Debug -Message  "Successfully processed $($allProcessedApps.Count) applications."
        Write-PSFMessage -Level Debug -Message  "  - Found throttling data for: $matchedCount applications"
        Write-PSFMessage -Level Debug -Message  "  - No activity for: $($allProcessedApps.Count - $matchedCount) applications"

        return $allProcessedApps
    }
}
