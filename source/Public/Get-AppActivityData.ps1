function Get-AppActivityData {
    <#
.SYNOPSIS
    Enriches application data with API activity information from Azure Log Analytics.

.DESCRIPTION
    This function queries Azure Log Analytics workspace to retrieve Microsoft Graph API activity
    for each application over a specified time period using PowerShell 7's native parallel processing.

    Uses ForEach-Object -Parallel for efficient concurrent execution while maintaining
    simplicity and native PowerShell functionality.

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
    - Parallel processing using PowerShell 7 native functionality (5-10x faster for large datasets)
    - Optimized parameter handling (pre-builds workspace parameters for efficiency)
    - Memory efficient processing with single-pass statistics gathering
    - Individual error handling (one failure doesn't stop processing)
    - Verbose logging for monitoring and progress tracking
    - Returns enhanced objects with Activity property and optional ErrorMessage for diagnostics

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
    The number of days of historical activity to retrieve, counting back from the current date.
    Default: 30 days

.PARAMETER ThrottleLimit
    The maximum number of concurrent runspaces to use for parallel processing.
    Valid range: 1-50 concurrent workers.
    Default: 10

    Recommended values:
    - **5**: Conservative for rate-limited environments
    - **10**: Balanced performance (default)
    - **20**: Aggressive for high-throughput scenarios

.PARAMETER MaxActivityEntries
    The maximum number of activity entries to retrieve per application from Log Analytics.
    This limits the result set size to prevent excessive data retrieval and memory consumption.
    Valid range: 1-500000 entries (Log Analytics limit).
    Default: 100000

    Recommended values:
    - **30000**: Conservative, faster queries
    - **100000**: Balanced (default)


.PARAMETER retainRawUri
    Optional switch. Returns cleaned but non-tokenized URIs when specified.
    Default behavior tokenizes URIs by replacing IDs with {id} placeholders.
    NOTE if you utilize this switch you will not be able to run a permission analysis on the endpoints

.OUTPUTS
    System.Object
    Returns the input application objects enriched with an "Activity" property containing the activity data.

    Additional Properties Added:
    - **Activity**: Array of activity records with Method, RequestUri, and TokenizedRequestUri
    - **ErrorMessage**: (Only if error occurred) Descriptive error message for troubleshooting

    Applications with no activity will have an empty Activity array. Applications with errors
    will have both an empty Activity array and an ErrorMessage property explaining the failure.

.EXAMPLE
    $apps | Get-AppActivityData -WorkspaceId $workspaceId -Days 90 -ThrottleLimit 20 -Verbose

    Queries activity data using the workspace ID (ByWorkspaceId parameter set).

.EXAMPLE
    $apps | Get-AppActivityData -subId $subscriptionId -rgName $resourceGroup -workspaceName $workspace -Days 30 -Verbose

    Queries activity data using workspace details (ByWorkspaceDetails parameter set) when using user_impersonation scope.

.NOTES
    Prerequisites:
    - PowerShell 7.0 or later (required for ForEach-Object -Parallel)
    - PSFramework module (for logging only)
    - EntraAuth module with active Log Analytics connection
    - Azure Log Analytics workspace with MicrosoftGraphActivityLogs table enabled
    - Must be authenticated via Connect-EntraService before calling this function

.LINK
    https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Get-AppActivityData.html
#>
    [CmdletBinding(DefaultParameterSetName = 'ByWorkspaceId')]
    [OutputType([System.Object])]
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
        [int]$Days = 30,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 50)]
        [int]$ThrottleLimit = 10,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 500000)]
        [int]$MaxActivityEntries = 100000,

        [Parameter(Mandatory = $false)]
        [switch]$retainRawUri
    )

    begin {
        $logAnalyticsToken = Get-EntraToken | Where-Object { $_.Service -eq 'LogAnalytics' }

        if (-not $logAnalyticsToken) {
            throw "Not authenticated to Log Analytics service. Please run Connect-EntraService -Service 'LogAnalytics' first."
        }

        Write-PSFMessage -Level Verbose -Message "Using existing Log Analytics authentication (expires: $($logAnalyticsToken.ValidUntil))"

        $allApps = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($app in $AppData) {
            $allApps.Add($app)
        }
    }

    end {
        Write-PSFMessage -Level Verbose -Message "Processing $($allApps.Count) applications with $ThrottleLimit concurrent threads..."

        # Get function definitions to pass into parallel scriptblock
        $getAppActivityFromLogDef = (Get-Command 'Get-AppActivityFromLog').Definition
        $convertRelativeUriToAbsoluteUriDef = (Get-Command 'Convert-RelativeUriToAbsoluteUri').Definition
        $convertToTokenizeIdDef = (Get-Command 'ConvertTo-TokenizeId').Definition

        # Pre-build workspace parameters to avoid repeated logic in parallel threads
        $workspaceParams = if ($PSCmdlet.ParameterSetName -eq 'ByWorkspaceId') {
            @{ logAnalyticsWorkspace = $WorkspaceId }
        }
        else {
            @{
                subId         = $subId
                rgName        = $rgName
                workspaceName = $workspaceName
            }
        }

        $results = $allApps | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
            $app = $_

            # Import function definitions (no need for $null assignment - ForEach-Object handles output)
            $null = New-Item -Path "function:Get-AppActivityFromLog" -Value ([scriptblock]::Create($using:getAppActivityFromLogDef)) -Force
            $null = New-Item -Path "function:Convert-RelativeUriToAbsoluteUri" -Value ([scriptblock]::Create($using:convertRelativeUriToAbsoluteUriDef)) -Force
            $null = New-Item -Path "function:ConvertTo-TokenizeId" -Value ([scriptblock]::Create($using:convertToTokenizeIdDef)) -Force

            # Wrap in try-catch to ensure object is always returned
            try {
                # Re-import token in parallel thread
                try {
                    Import-EntraToken -Token $using:logAnalyticsToken -NoRenew
                }
                catch {
                    $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
                    $app | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value "Auth failed: $($_.Exception.Message)" -Force
                    return $app
                }

                # Get activity data - merge pre-built workspace parameters with runtime parameters
                try {
                    $activityParams = @{
                        days               = $using:Days
                        spId               = $app.PrincipalId
                        maxActivityEntries = $using:MaxActivityEntries
                        retainRawUri       = $using:retainRawUri
                    }

                    # Merge workspace-specific parameters (capture $using: variable first to avoid indexer limitation)
                    $workspaceParams = $using:workspaceParams
                    foreach ($key in $workspaceParams.Keys) {
                        $activityParams[$key] = $workspaceParams[$key]
                    }

                    $activity = Get-AppActivityFromLog @activityParams
                    $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value $activity -Force
                }
                catch {
                    $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
                    $app | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value "Query failed: $($_.Exception.Message)" -Force
                }
            }
            catch {
                $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
                $app | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value "Unexpected error: $($_.Exception.Message)" -Force
            }

            # Always return the object
            return $app
        }

        Write-PSFMessage -Level Verbose -Message "Completed processing: $($results.Count)/$($allApps.Count) applications."

        # Single-pass statistics gathering for better performance
        $enrichedCount = 0
        $errorCount = 0
        $errorExamples = [System.Collections.Generic.List[object]]::new()

        foreach ($result in $results) {
            if ($result.Activity -and $result.Activity.Count -gt 0) {
                $enrichedCount++
            }
            if ($result.ErrorMessage) {
                $errorCount++
                if ($errorExamples.Count -lt 3) {
                    $errorExamples.Add($result)
                }
            }
        }

        if ($errorCount -gt 0) {
            Write-PSFMessage -Level Warning -Message "$errorCount applications had errors. Check objects with ErrorMessage property."
            # Show first few errors as examples
            foreach ($errorApp in $errorExamples) {
                Write-PSFMessage -Level Warning -Message "Example error - $($errorApp.PrincipalName): $($errorApp.ErrorMessage)"
            }
        }

        Write-PSFMessage -Level Verbose -Message "Successfully enriched $enrichedCount applications with activity data."

        $results
    }
}
