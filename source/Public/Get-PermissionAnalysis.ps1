function Get-PermissionAnalysis {
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
    This workspace must contain the MicrosoftGraphActivityLogs table with throttling information.

    Format: GUID string (e.g., "12345678-1234-1234-1234-123456789012")

    To find your workspace ID:
    1. Navigate to Azure Portal > Log Analytics workspaces
    2. Select your workspace
    3. Copy the Workspace ID from the Overview page

    Prerequisites:
    - Microsoft Graph diagnostic settings enabled and sending to this workspace
    - You must have permissions to query the workspace
    - MicrosoftGraphActivityLogs table must contain data

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

.EXAMPLE
    $results = $apps | Get-AppThrottlingData -WorkspaceId $workspaceId -Days 30

    # Categorize applications by throttling status
    $statusSummary = $results | Group-Object {$_.ThrottlingStats.ThrottlingStatus} |
        Select-Object Name, Count, @{
            Name='Applications'
            Expression={$_.Group.PrincipalName -join ', '}
        }

    "`nThrottling Status Summary:"
    $statusSummary | Format-Table -AutoSize

    # Export detailed report
    $results | Where-Object { $_.ThrottlingStats.ThrottlingStatus -ne 'No Activity' } |
        Select-Object PrincipalName, PrincipalId,
            @{N='Status';E={$_.ThrottlingStats.ThrottlingStatus}},
            @{N='Throttle Rate';E={$_.ThrottlingStats.ThrottleRate}},
            @{N='Total Requests';E={$_.ThrottlingStats.TotalRequests}},
            @{N='429 Errors';E={$_.ThrottlingStats.Total429Errors}} |
        Export-Csv -Path "throttling-report.csv" -NoTypeInformation

    Description:
    Creates a comprehensive throttling report with summary statistics and detailed CSV export
    for all active applications.

.EXAMPLE
    # Monitor specific application over time
    $app = Get-MgServicePrincipal -Filter "displayName eq 'Critical Production App'"
    $throttling = $app | Get-AppThrottlingData -WorkspaceId $workspaceId -Days 7

    $stats = $throttling.ThrottlingStats

    "`nThrottling Report for: $($app.DisplayName)"
    "Analysis Period: Last 7 days"
    "`nRequest Statistics:"
    "  Total Requests: $($stats.TotalRequests)"
    "  Successful: $($stats.SuccessfulRequests) ($($stats.SuccessRate)%)"
    "  Failed: $($stats.TotalClientErrors + $stats.TotalServerErrors) ($($stats.ErrorRate)%)"
    "`nThrottling Details:"
    "  429 Errors: $($stats.Total429Errors)"
    "  Throttle Rate: $($stats.ThrottleRate)%"
    "  Severity: $($stats.ThrottlingSeverity) - $($stats.ThrottlingStatus)"
    "`nTime Range:"
    "  First Request: $($stats.FirstOccurrence)"
    "  Last Request: $($stats.LastOccurrence)"

    if ($stats.ThrottlingSeverity -ge 3) {
        Write-Warning "`nRECOMMENDATION: Implement retry logic with exponential backoff and request batching"
    }

    Description:
    Generates a detailed, formatted throttling report for a specific application with
    color-coded severity and actionable recommendations.

.EXAMPLE
    # Compare current vs. previous period
    $apps = Get-MgServicePrincipal -All
    $currentPeriod = $apps | Get-AppThrottlingData -WorkspaceId $workspaceId -Days 30

    # Load previous period data (run this monthly and save results)
    if (Test-Path "previous-throttling.xml") {
        $previousPeriod = Import-Clixml -Path "previous-throttling.xml"

        $comparison = $currentPeriod | ForEach-Object {
            $current = $_
            $previous = $previousPeriod | Where-Object { $_.PrincipalId -eq $current.PrincipalId }

            if ($previous) {
                $throttleChange = $current.ThrottlingStats.ThrottleRate - $previous.ThrottlingStats.ThrottleRate

                [PSCustomObject]@{
                    AppName = $current.PrincipalName
                    PreviousRate = $previous.ThrottlingStats.ThrottleRate
                    CurrentRate = $current.ThrottlingStats.ThrottleRate
                    Change = $throttleChange
                    Trend = if ($throttleChange -gt 2) { " Worsening" }
                           elseif ($throttleChange -lt -2) { " Improving" }
                           else { "-> Stable" }
                    PreviousStatus = $previous.ThrottlingStats.ThrottlingStatus
                    CurrentStatus = $current.ThrottlingStats.ThrottlingStatus
                }
            }
        }

        $worsening = $comparison | Where-Object { $_.Change -gt 2 }
        if ($worsening) {
            Write-Warning "`nApplications with Worsening Throttling:"
            $worsening | Sort-Object Change -Descending | Format-Table -AutoSize
        }
    }

    # Save current period for next comparison
    $currentPeriod | Export-Clixml -Path "previous-throttling.xml" -Force

    Description:
    Implements trend analysis by comparing throttling rates between time periods to identify
    applications with degrading performance.

.EXAMPLE
    # Automated monitoring with alerting
    $apps = Get-MgServicePrincipal -All
    $throttlingData = $apps | Get-AppThrottlingData -WorkspaceId $workspaceId -Days 1

    $alerts = $throttlingData | Where-Object {
        $_.ThrottlingStats.ThrottlingSeverity -ge 3 -and
        $_.ThrottlingStats.Total429Errors -gt 50
    }

    if ($alerts.Count -gt 0) {
        $emailBody = @"
Throttling Alert: $($alerts.Count) applications experiencing significant API throttling

Critical Applications:
$(
    $alerts | ForEach-Object {
        "- $($_.PrincipalName): $($_.ThrottlingStats.Total429Errors) throttling errors ($($_.ThrottlingStats.ThrottleRate)% throttle rate)"
    } | Out-String
)

Recommendations:
1. Review applications for excessive API calls
2. Implement retry logic with exponential backoff
3. Consider request batching for bulk operations
4. Check for polling patterns that could be replaced with webhooks

Report generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@

        Send-MailMessage -To "ops-team@contoso.com" -From "monitoring@contoso.com" `
            -Subject "Graph API Throttling Alert - $($alerts.Count) Apps Affected" `
            -Body $emailBody -SmtpServer "smtp.contoso.com"

        "Alert sent for $($alerts.Count) applications"
    }
    else {
        "All applications within normal throttling thresholds"
    }

    Description:
    Implements automated daily monitoring that sends email alerts when applications exceed
    throttling thresholds. Can be scheduled as an Azure Automation runbook or scheduled task.

.EXAMPLE
    # Generate executive dashboard data
    $apps = Get-MgServicePrincipal -All
    $data = $apps | Get-AppThrottlingData -WorkspaceId $workspaceId -Days 30

    $dashboard = [PSCustomObject]@{
        ReportDate = Get-Date -Format "yyyy-MM-dd"
        TotalApplications = $data.Count
        ActiveApplications = ($data | Where-Object { $_.ThrottlingStats.TotalRequests -gt 0 }).Count
        TotalRequests = ($data.ThrottlingStats.TotalRequests | Measure-Object -Sum).Sum
        TotalThrottlingErrors = ($data.ThrottlingStats.Total429Errors | Measure-Object -Sum).Sum
        OverallThrottleRate = [math]::Round(
            (($data.ThrottlingStats.Total429Errors | Measure-Object -Sum).Sum /
             ($data.ThrottlingStats.TotalRequests | Measure-Object -Sum).Sum * 100), 2
        )
        CriticalApps = ($data | Where-Object { $_.ThrottlingStats.ThrottlingSeverity -eq 4 }).Count
        WarningApps = ($data | Where-Object { $_.ThrottlingStats.ThrottlingSeverity -eq 3 }).Count
        HealthyApps = ($data | Where-Object { $_.ThrottlingStats.ThrottlingSeverity -le 1 }).Count
    }

    "`n=== Microsoft Graph API Health Dashboard ==="
    $dashboard | Format-List

    $dashboard | Export-Csv -Path "dashboard-$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation

    Description:
    Creates executive-level dashboard metrics showing overall API health across the tenant,
    suitable for management reporting and capacity planning.

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
    - **Write-Debug**: Detailed per-app processing and matching logic
    - **Write-Verbose**: Match results, sample data, and lookup table size
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
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        [array]$AppData
    )

    begin {
        $moduleRoot = $MyInvocation.MyCommand.Module.ModuleBase

        $PermissionMapV1Path = Join-Path -Path $moduleRoot -ChildPath "data\permissions-v1.0.json"
        $PermissionMapBetaPath = Join-Path -Path $moduleRoot -ChildPath "data\permissions-beta.json"

        Write-Debug "Module root: $moduleRoot"
        Write-Debug "Loading permission maps..."
        Write-Debug "V1 Path: $PermissionMapV1Path"
        Write-Debug "Beta Path: $PermissionMapBetaPath"

        # Validate files exist
        if (-not (Test-Path -Path $PermissionMapV1Path)) {
            throw "Permission map file not found: $PermissionMapV1Path"
        }
        if (-not (Test-Path -Path $PermissionMapBetaPath)) {
            throw "Permission map file not found: $PermissionMapBetaPath"
        }

        $permissionMapv1 = Get-Content -Path $PermissionMapV1Path -Raw | ConvertFrom-Json
        $permissionMapbeta = Get-Content -Path $PermissionMapBetaPath -Raw | ConvertFrom-Json

        Write-Debug "Permission maps loaded successfully"
    }

    process {
        # Handle null or empty input
        if ($null -eq $AppData -or $AppData.Count -eq 0) {
            Write-Debug "No app data provided in this pipeline iteration"
            return
        }

        foreach ($app in $AppData) {
            # Skip null or invalid entries
            if ($null -eq $app) {
                Write-Debug "Skipping null app entry"
                continue
            }

            # Validate required properties
            if (-not $app.PrincipalName) {
                Write-Warning "Skipping app without PrincipalName property"
                continue
            }

            Write-Debug "`nAnalyzing: $($app.PrincipalName)"

            # Handle apps without activity
            if ($null -eq $app.Activity -or $app.Activity.Count -eq 0) {
                Write-Debug "  No activity found for $($app.PrincipalName)"

                # Add empty analysis properties
                $app | Add-Member -MemberType NoteProperty -Name "ActivityPermissions" -Value @() -Force
                $app | Add-Member -MemberType NoteProperty -Name "OptimalPermissions" -Value @() -Force
                $app | Add-Member -MemberType NoteProperty -Name "UnmatchedActivities" -Value @() -Force

                $currentPermissions = if ($app.AppRoles) {
                    $app.AppRoles | Select-Object -ExpandProperty FriendlyName | Where-Object { $_ -ne $null }
                }
                else {
                    @()
                }

                $app | Add-Member -MemberType NoteProperty -Name "CurrentPermissions" -Value $currentPermissions -Force
                $app | Add-Member -MemberType NoteProperty -Name "ExcessPermissions" -Value @() -Force
                $app | Add-Member -MemberType NoteProperty -Name "RequiredPermissions" -Value @() -Force
                $app | Add-Member -MemberType NoteProperty -Name "MatchedAllActivity" -Value $true -Force

                # Output the app immediately
                Write-Output $app
                continue
            }

            # Find least privileged permissions for each activity
            $splatLeastPrivileged = @{
                userActivity      = $app.Activity
                permissionMapv1   = $permissionMapv1
                permissionMapbeta = $permissionMapbeta
            }
            $activityPermissions = Find-LeastPrivilegedPermission @splatLeastPrivileged

            # Get optimal permission set
            $optimalSet = Get-OptimalPermissionSet -activityPermissions $activityPermissions

            # Add results to app object
            $app | Add-Member -MemberType NoteProperty -Name "ActivityPermissions" -Value $activityPermissions -Force
            $app | Add-Member -MemberType NoteProperty -Name "OptimalPermissions" -Value $optimalSet.OptimalPermissions -Force
            $app | Add-Member -MemberType NoteProperty -Name "UnmatchedActivities" -Value $optimalSet.UnmatchedActivities -Force

            # Compare with current permissions
            $currentPermissions = if ($app.AppRoles) {
                $app.AppRoles | Select-Object -ExpandProperty FriendlyName | Where-Object { $_ -ne $null }
            }
            else {
                @()
            }

            $optimalPermissionNames = $optimalSet.OptimalPermissions | Select-Object -ExpandProperty Permission -Unique

            $excessPermissions = $currentPermissions | Where-Object { $optimalPermissionNames -notcontains $_ }
            $missingPermissions = $optimalPermissionNames | Where-Object { $currentPermissions -notcontains $_ }

            $app | Add-Member -MemberType NoteProperty -Name "CurrentPermissions" -Value $currentPermissions -Force
            $app | Add-Member -MemberType NoteProperty -Name "ExcessPermissions" -Value $excessPermissions -Force
            $app | Add-Member -MemberType NoteProperty -Name "RequiredPermissions" -Value $missingPermissions -Force

            $matchedAllActivity = if ($optimalSet.UnmatchedActivities -and $optimalSet.UnmatchedActivities.Count -gt 0) {
                $false
            }
            else {
                $true
            }
            $app | Add-Member -MemberType NoteProperty -Name "MatchedAllActivity" -Value $matchedAllActivity -Force

            # Display summary
            Write-Debug "  Matched Activities: $($optimalSet.MatchedActivities)/$($optimalSet.TotalActivities)"
            Write-Debug "  Optimal Permissions: $($optimalSet.OptimalPermissions.Count)"
            Write-Debug "  Current Permissions: $($currentPermissions.Count)"
            Write-Debug "  Excess Permissions: $($excessPermissions.Count)"

            # Output the app immediately to the pipeline
            Write-Output $app
        }
    }
}
