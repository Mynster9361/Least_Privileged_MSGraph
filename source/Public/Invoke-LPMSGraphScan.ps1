function Invoke-LPMSGraphScan {
    <#
.SYNOPSIS
    Executes a complete Microsoft Graph least privilege analysis workflow from data collection to report generation.

.DESCRIPTION
    This function orchestrates the entire least privileged permission analysis process by executing
    a comprehensive workflow that combines data retrieval, activity analysis, and report generation
    into a single streamlined operation.

    The workflow performs the following steps in sequence:
    1. **Retrieves app role assignments** - Gets all applications with Microsoft Graph permissions
    2. **Collects activity data** - Queries Log Analytics for actual API usage over specified time period
    3. **Gathers throttling data** (optional) - Identifies apps experiencing rate limiting
    4. **Analyzes permissions** - Compares assigned vs. used permissions to identify least privileged set
    5. **Generates HTML report** - Creates comprehensive visualization with recommendations

    This function is designed as a "one-command" solution for permission audits, eliminating
    the need to manually chain multiple commands together. It handles the complete data flow
    through the pipeline while providing comprehensive logging and error handling.

    Use Cases:
    - Quick permission audits without manual workflow orchestration
    - Scheduled/automated compliance reporting
    - Initial assessment of tenant permission posture
    - Regular permission optimization reviews
    - Security team dashboards and reporting

    Requirements:
    - Active connection to Microsoft Graph with sufficient permissions
    - Azure Log Analytics workspace with Microsoft Graph diagnostic logs enabled
    - Appropriate Azure permissions to query Log Analytics data

.PARAMETER WorkspaceId
    The full Azure Resource Manager resource ID of the Log Analytics workspace.
    Used with the 'ByWorkspaceId' parameter set.

    Format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/{workspaceName}

    Example: "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-graphlogs"

    Mutually exclusive with subId, rgName, and workspaceName parameters.

.PARAMETER subId
    Azure subscription ID (GUID) where the Log Analytics workspace is located.
    Used with the 'ByWorkspaceDetails' parameter set when you want to specify workspace details separately.

    Example: "12345678-1234-1234-1234-123456789012"

    Required together with rgName and workspaceName parameters.

.PARAMETER rgName
    Azure resource group name where the Log Analytics workspace is located.
    Used with the 'ByWorkspaceDetails' parameter set.

    Example: "rg-monitoring"

    Required together with subId and workspaceName parameters.

.PARAMETER workspaceName
    Log Analytics workspace name.
    Used with the 'ByWorkspaceDetails' parameter set.

    Example: "law-graphlogs"

    Required together with subId and rgName parameters.

.PARAMETER ExcludeThrottleData
    Switch parameter to skip the throttling data collection step.
    Default: $false (throttling data IS collected by default)

    Use this switch when:
    - You want faster execution and don't need throttling insights
    - Your workspace doesn't have throttling data available
    - You're only interested in permission optimization, not performance issues

.PARAMETER Days
    The number of days of historical activity to analyze, counting back from the current date.
    Default: 30 days

    Recommended values:
    - **7**: Quick analysis, recent activity only
    - **30**: Balanced view (default) - captures monthly patterns
    - **90**: Comprehensive analysis including seasonal variations

    Note: Longer periods provide better coverage but increase query time and data processing.

.PARAMETER ThrottleLimit
    The maximum number of concurrent runspaces to use for parallel processing of applications.
    Default: 20
    Valid range: 1-50

    Recommended values:
    - **10**: Conservative for rate-limited environments
    - **20**: Balanced performance (default)
    - **30**: Aggressive for high-throughput scenarios with many applications

.PARAMETER MaxActivityEntries
    The maximum number of activity log entries to retrieve per application from Log Analytics.
    Default: 100000
    Valid range: 1-500000 (Log Analytics limit)

    This prevents excessive data retrieval for very active applications while still
    capturing comprehensive usage patterns. Most applications will have fewer entries
    than this limit for typical analysis periods.

.PARAMETER OutputPath
    The file path where the HTML report should be generated.
    Default: ".\report.html" (current directory)

    Supports absolute and relative paths. The directory will be created if it doesn't exist.

    Example: "C:\Reports\GraphPermissions\audit-2024-12.html"

.OUTPUTS
    None
    This function generates an HTML report file at the specified OutputPath.
    The report contains visualizations and recommendations for permission optimization.
    Progress and status information is written to the verbose and information streams.

.EXAMPLE
    Initialize-LogAnalyticsApi
    Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret -Service "GraphBeta", "LogAnalytics"
    Invoke-LPMSGraphScan -WorkspaceId "123456-workspace-id-456"

    Description:
    Executes a complete scan using all default parameters:
    - Analyzes last 30 days of activity
    - Includes throttling data
    - Uses 20 parallel workers
    - Retrieves up to 100,000 activity entries per app
    - Generates report.html in the current directory

.EXAMPLE
    Invoke-LPMSGraphScan -subId "12345678-1234-1234-1234-123456789012" -rgName "rg-monitoring" -workspaceName "law-graphlogs" -Days 90 -OutputPath "C:\Reports\Q4-audit.html" -Verbose

    Description:
    Executes scan by specifying workspace details separately:
    - Constructs full workspace resource ID from components
    - Analyzes 90 days of historical activity
    - Includes verbose logging for monitoring
    - Generates report at specified path

.EXAMPLE
    Invoke-LPMSGraphScan -WorkspaceId $workspaceId -ExcludeThrottleData -Days 7 -ThrottleLimit 10 -OutputPath ".\quick-check.html"

    Description:
    Executes a quick permission check:
    - Only analyzes last 7 days
    - Skips throttling data collection for faster execution
    - Uses conservative parallelization (10 workers)
    - Suitable for rapid assessments or testing

.EXAMPLE
    $params = @{
        WorkspaceId = "/subscriptions/sub-123/resourceGroups/rg-logs/providers/Microsoft.OperationalInsights/workspaces/law-graph"
        Days = 60
        ThrottleLimit = 30
        MaxActivityEntries = 200000
        OutputPath = ".\enterprise-audit.html"
    }
    Invoke-LPMSGraphScan @params -Verbose

    Description:
    Enterprise-scale scan with optimized parameters:
    - 60-day analysis period for comprehensive coverage
    - Higher parallelization (30 workers) for faster processing
    - Increased activity entry limit for very active applications
    - Verbose output for monitoring large-scale execution

.NOTES

    This function requires:
    - EntraAuth module for Graph authentication
    - PSFramework module for parallel processing
    - Active Graph connection with appropriate permissions
    - Log Analytics workspace with Graph diagnostic logs

    Error Handling:
    - Returns early if no app role assignments are found
    - Propagates errors from individual workflow steps
    - Provides detailed error messages for troubleshooting

#>
    [CmdletBinding()]
    param (
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
        [switch]$ExcludeThrottleData = $false,

        [Parameter(Mandatory = $false)]
        [int]$Days = 30,

        [Parameter(Mandatory = $false)]
        [int]$ThrottleLimit = 20,

        [Parameter(Mandatory = $false)]
        [int]$MaxActivityEntries = 100000,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = ".\report.html"
    )

    begin {
        Write-Verbose "Starting LPMSGraph scan workflow"
        $variables = @{}

        if ($PSCmdlet.ParameterSetName -eq 'ByWorkspaceId') {
            $variables['WorkspaceId'] = $WorkspaceId
        }
        else {
            $variables['subId'] = $subId
            $variables['rgName'] = $rgName
            $variables['workspaceName'] = $workspaceName
        }
    }

    process {
        try {
            Write-Verbose "Retrieving app role assignments..."
            $appData = Get-AppRoleAssignment

            if (-not $appData) {
                Write-Warning "No app role assignments found"
                return
            }

            Write-Verbose "Found $($appData.Count) app role assignment(s)"

            Write-Verbose "Retrieving app activity data for the last $Days days..."
            $appData = $appData | Get-AppActivityData @variables -Days $Days -ThrottleLimit $ThrottleLimit -MaxActivityEntries $MaxActivityEntries

            if (-not $ExcludeThrottleData) {
                Write-Verbose "Retrieving app throttling data..."
                $appData = $appData | Get-AppThrottlingData @variables -Days $Days
            }
            else {
                Write-Verbose "Skipping throttling data collection"
            }

            Write-Verbose "Performing permission analysis..."
            $appData = $appData | Get-PermissionAnalysis

            Write-Verbose "Exporting report to: $OutputPath"
            Export-PermissionAnalysisReport -AppData $appData -OutputPath $OutputPath

            Write-Verbose "Scan completed successfully"
        }
        catch {
            Write-Error "An error occurred during the scan: $_"
            throw
        }
    }

    end {
        Write-Verbose "LPMSGraph scan workflow completed"
    }
}
