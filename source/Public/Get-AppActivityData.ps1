function Get-AppActivityData {
    <#
.SYNOPSIS
    Enriches application data with API activity information from Azure Log Analytics.

.DESCRIPTION
    This function queries Azure Log Analytics workspace to retrieve Microsoft Graph API activity
    for each application over a specified time period. It adds the activity data as a new property
    to each application object, enabling analysis of what API calls each application has made.

    The function processes applications efficiently using PowerShell pipeline streaming, meaning
    each application is processed and output immediately without storing all results in memory.
    This approach significantly reduces memory usage, especially for large tenants with hundreds
    or thousands of applications.

    Activity data includes:
    - HTTP methods used (GET, POST, PUT, PATCH, DELETE, etc.)
    - API endpoints accessed (normalized and tokenized for pattern matching)
    - Unique method/URI combinations (deduplicated)
    - Tokenized URIs with {id} placeholders for permission mapping

    This data is essential for:
    - Determining least privileged permissions based on actual API usage
    - Identifying unused permissions that can be removed
    - Understanding application behavior and API consumption patterns
    - Auditing what Graph API operations applications perform
    - Planning permission optimization initiatives

    Key Features:
    - True pipeline streaming for minimal memory footprint
    - Individual error handling (one failure doesn't stop processing)
    - Verbose logging for monitoring
    - Debug output for troubleshooting
    - Progress tracking with item count
    - Returns enhanced objects with Activity property

.PARAMETER AppData
    An array of application objects to enrich with activity data. Each object must contain:

    Required Properties:
    - **PrincipalId** (String): The Azure AD service principal object ID
    - **PrincipalName** (String): The application display name (used for logging/progress)

    Optional Properties:
    - Any other properties are preserved and passed through
    - Common properties: AppId, Tags, AppRoles, etc.

    This parameter accepts pipeline input, allowing you to pipe application objects directly
    from Get-MgServicePrincipal or other sources.

    Example application object:
    @{
        PrincipalId = "12345678-1234-1234-1234-123456789012"
        PrincipalName = "My Application"
        AppId = "87654321-4321-4321-4321-210987654321"
    }

.PARAMETER WorkspaceId
    The Azure Log Analytics workspace ID (GUID) where Microsoft Graph activity logs are stored.
    This workspace must contain the MicrosoftGraphActivityLogs table with diagnostic logging enabled.

    Format: GUID string (e.g., "12345678-1234-1234-1234-123456789012")

    To find your workspace ID:
    1. Navigate to Azure Portal > Log Analytics workspaces
    2. Select your workspace
    3. Copy the Workspace ID from the Overview page

    Prerequisites:
    - Microsoft Graph diagnostic settings must send logs to this workspace
    - You must have permissions to query the workspace (Log Analytics Reader role or equivalent)
    - Logs typically appear within 10-15 minutes of API activity

.PARAMETER Days
    The number of days of historical activity to retrieve, counting back from the current date.

    Default: 30 days

    Recommended values:
    - **7 days**: Quick analysis for recently active applications
    - **30 days**: Standard monthly review (default)
    - **90 days**: Comprehensive quarterly analysis for thorough coverage

    Considerations:
    - Longer periods provide more complete data but take longer to process
    - Applications with infrequent activity need longer periods
    - Balance between data completeness and query performance
    - Maximum limited by workspace retention period (typically 30-730 days)

.OUTPUTS
    System.Object
    Returns the input application objects enriched with an "Activity" property.
    Objects are streamed through the pipeline as they are processed.

    Activity Property Structure:
    - Type: Array of objects
    - Each activity object contains:
      * Method (String): HTTP method (GET, POST, PUT, PATCH, DELETE, etc.)
      * Uri (String): Tokenized API endpoint with {id} placeholders
        Example: "https://graph.microsoft.com/v1.0/users/{id}/messages"

    Special Cases:
    - Empty array (@()): No activity found for that application
    - Empty array (@()): Error occurred querying Log Analytics (warning logged)
    - Null Activity property should never occur (always set to at least empty array)

    The function also outputs a summary string at the end indicating successful processing count.

.EXAMPLE
    $apps = Get-MgServicePrincipal -Filter "appId eq 'your-app-id'"
    $enrichedApps = $apps | Get-AppActivityData -WorkspaceId "12345678-abcd-efgh-ijkl-123456789012"

    Description:
    Retrieves activity for a specific application over the default 30-day period.
    The returned object includes an Activity property with API calls made by the application.

.EXAMPLE
    $allApps = Get-MgServicePrincipal -All | Where-Object { $_.AppRoles.Count -gt 0 }
    $appsWithActivity = $allApps | Get-AppActivityData -WorkspaceId $workspaceId -Days 90
    $activeApps = $appsWithActivity | Where-Object { $_.Activity.Count -gt 0 }

    "Found $($activeApps.Count) applications with activity in the last 90 days"
    $activeApps | Select-Object PrincipalName, @{N='ActivityCount';E={$_.Activity.Count}} | Format-Table

    Description:
    Analyzes 90 days of activity for all service principals with Graph permissions,
    filters to only those with activity, and displays a summary table.

.EXAMPLE
    $apps = Get-Content .\apps.json | ConvertFrom-Json
    $results = Get-AppActivityData -AppData $apps -WorkspaceId $workspaceId -Days 7 -Verbose
    $results | Export-Clixml .\enriched-apps.xml

    "Saved enriched app data to enriched-apps.xml"

    Description:
    Loads applications from JSON, gets 7 days of activity with verbose output,
    and saves the enriched results to XML for later analysis or reporting.

.EXAMPLE
    $criticalApps = Get-MgServicePrincipal -Filter "tags/any(t:t eq 'Critical')"
    $criticalApps | Get-AppActivityData -WorkspaceId $workspaceId -Days 30 |
        ForEach-Object {
            if ($_.Activity.Count -eq 0) {
                Write-Warning "$($_.PrincipalName) has no recent activity - consider reviewing permissions"
            } else {
                "$($_.PrincipalName): $($_.Activity.Count) unique API patterns"
            }
        }

    Description:
    Monitors critical applications for activity and alerts if any have been inactive
    for 30 days, which may indicate unused permissions or dormant applications.

.EXAMPLE
    # Process entire tenant with streaming pipeline - minimal memory usage
    Get-MgServicePrincipal -All |
        Get-AppActivityData -WorkspaceId $workspaceId -Days 30 -Verbose |
        Export-Clixml .\all-apps-with-activity.xml

    Description:
    Processes all service principals in the tenant using pipeline streaming.
    Each app is processed and written to the XML file as it completes, minimizing
    memory usage regardless of tenant size.

.EXAMPLE
    # Compare activity across different time periods
    $apps = Get-MgServicePrincipal -Top 10

    $recent = $apps | Get-AppActivityData -WorkspaceId $workspaceId -Days 7
    $extended = $apps | Get-AppActivityData -WorkspaceId $workspaceId -Days 90

    foreach ($app in $recent) {
        $extendedApp = $extended | Where-Object { $_.PrincipalId -eq $app.PrincipalId }

        "`n$($app.PrincipalName):"
        "  Last 7 days: $($app.Activity.Count) unique patterns"
        "  Last 90 days: $($extendedApp.Activity.Count) unique patterns"

        if ($extendedApp.Activity.Count -gt $app.Activity.Count * 2) {
            Write-Warning "  Application has irregular activity patterns - review needed"
        }
    }

    Description:
    Compares activity patterns across different time periods to identify applications
    with irregular or seasonal usage patterns.

.EXAMPLE
    # Generate activity summary report with streaming
    Get-MgServicePrincipal -All |
        Get-AppActivityData -WorkspaceId $workspaceId -Days 30 |
        ForEach-Object {
            [PSCustomObject]@{
                ApplicationName = $_.PrincipalName
                AppId = $_.AppId
                UniqueEndpoints = $_.Activity.Count
                HasActivity = $_.Activity.Count -gt 0
                Methods = ($_.Activity.Method | Select-Object -Unique) -join ', '
                SampleEndpoint = if ($_.Activity.Count -gt 0) { $_.Activity[0].Uri } else { "None" }
            }
        } | Export-Csv -Path ".\app-activity-summary.csv" -NoTypeInformation

    "Activity summary exported to app-activity-summary.csv"

    Description:
    Creates a comprehensive summary CSV report showing activity metrics for all applications
    using efficient pipeline streaming. Memory usage remains constant regardless of tenant size.

.NOTES
    Prerequisites:
    - PowerShell 5.1 or later
    - Azure Log Analytics workspace with MicrosoftGraphActivityLogs table enabled
    - Microsoft Graph diagnostic settings configured to send logs to the workspace
    - Appropriate permissions to query the Log Analytics workspace via Invoke-EntraRequest
    - Get-AppActivityFromLog function must be available (private function dependency)

    Log Analytics Configuration:
    To enable Microsoft Graph activity logging:
    1. Navigate to Azure AD > Diagnostic settings
    2. Add diagnostic setting
    3. Select "MicrosoftGraphActivityLogs" log category
    4. Send to Log Analytics workspace
    5. Wait 10-15 minutes for initial data to appear
    6. Verify data: Run query in Log Analytics: MicrosoftGraphActivityLogs | take 10

    Performance Considerations:
    - Processing time scales linearly with the number of applications
    - Each application requires a separate Log Analytics query
    - Typical processing time: 1-2 seconds per application
    - Large tenants (500+ apps) may take 10-15 minutes
    - Network latency affects query time
    - Log Analytics query throttling may occur with rapid requests

    Memory Usage:
    - Uses true pipeline streaming - only one application in memory at a time
    - Constant memory usage regardless of tenant size (O(1) complexity)
    - Activity data for each app is immediately passed downstream and released
    - Ideal for large tenants with thousands of applications
    - No risk of out-of-memory exceptions from storing results

    Pipeline Streaming:
    - Each application is processed in the process{} block
    - Results are immediately output to the pipeline
    - Downstream commands (like Export-Csv) receive items as they're ready
    - Memory footprint stays minimal throughout execution
    - Example: Get-MgServicePrincipal | Get-AppActivityData | Export-Csv
      Only one service principal and one enriched result in memory at any time

    Error Handling:
    - Individual failures are logged as warnings (Write-Warning)
    - Processing continues even if some queries fail
    - Failed applications receive an empty Activity array (@())
    - Progress tracking continues regardless of individual failures
    - Final count reflects successfully processed apps (may be less than input)

    Progress Tracking:
    - Progress bar shows: current app being processed
    - Updates after each application is processed
    - Includes current operation (app name and ID)
    - Shows running count of processed items
    - Automatically completes when processing finishes
    - Note: Total count/percentage not available due to streaming (memory optimization)

    Logging Levels:
    - **Write-Debug**: Detailed per-app processing information (use -Debug)
    - **Write-Verbose**: Processing milestones and counts (use -Verbose)
    - **Write-Warning**: Individual query failures and issues
    - **Write-Progress**: Visual progress bar (always shown)
    - **Standard Output**: Final summary message

    Common Issues:

    No activity found for any applications:
    - Verify Microsoft Graph logging is enabled
    - Check Log Analytics workspace ID is correct
    - Ensure diagnostic settings are sending to correct workspace
    - Increase -Days parameter (applications may have infrequent activity)
    - Verify service principals have actually made API calls

    Slow processing:
    - This is normal for large numbers of applications
    - Check Log Analytics workspace location (cross-region queries slower)
    - Verify network connectivity to Azure

    Authentication failures:
    - Ensure Invoke-EntraRequest is configured with valid credentials
    - Verify permissions to read from Log Analytics workspace
    - Check if authentication token has expired (re-authenticate)

    Return Value:
    - Function returns enriched objects via pipeline streaming
    - Summary message goes to standard output at the end
    - Use Out-Null if you want to suppress the summary message

    Best Practices:
    - Always use -Verbose for long-running operations
    - Use Export-Clixml or Export-Csv to save results as they stream through
    - Leverage pipeline streaming for large datasets
    - Monitor progress bar for stuck queries
    - Test with small application sets before processing entire tenant

    Related Cmdlets:
    - Get-MgServicePrincipal: Retrieve applications to analyze
    - Get-PermissionAnalysis: Next step after getting activity data
    - Export-PermissionAnalysisReport: Generate reports from analysis results

.LINK
    https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Get-AppActivityData.html
#>
    [CmdletBinding()]
    [OutputType([System.Object])]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [array]$AppData,

        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,

        [Parameter(Mandatory = $false)]
        [int]$Days = 30
    )

    begin {
        Write-Debug "Starting to get app activity data from Log Analytics..."
        $processedCount = 0
    }

    process {
        # Process each app as it comes through the pipeline
        foreach ($app in $AppData) {
            $processedCount++
            $spId = $app.PrincipalId

            # Update progress bar with current item (no percentage, as we don't know total)
            $progressParams = @{
                Activity         = "Querying Log Analytics for Application Activity"
                Status           = "Processing application #$processedCount"
                CurrentOperation = "$($app.PrincipalName) (ID: $spId)"
            }
            Write-Progress @progressParams

            Write-Debug "[$processedCount] Querying activity for $($app.PrincipalName) ($spId)..."

            try {
                $activity = Get-AppActivityFromLog -logAnalyticsWorkspace $WorkspaceId -days $Days -spId $spId

                if ($null -ne $activity) {
                    $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value $activity -Force
                    Write-Debug "Found $($activity.Count) activities for $($app.PrincipalName)."
                }
                else {
                    $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
                    Write-Debug "No activity found for $($app.PrincipalName)."
                }
            }
            catch {
                Write-Warning "Error retrieving activity for $($app.PrincipalName): $_"
                $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
            }

            # Output the enriched app object immediately to the pipeline
            $app
        }
    }

    end {
        # Complete the progress bar
        Write-Progress -Activity "Querying Log Analytics for Application Activity" -Completed

        Write-Verbose "Successfully processed $processedCount applications."
    }
}
