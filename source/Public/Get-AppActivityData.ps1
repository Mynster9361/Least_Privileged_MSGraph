function Get-AppActivityData {
    <#
.SYNOPSIS
    Enriches application data with API activity information from Azure Log Analytics.

.DESCRIPTION
    This function queries Azure Log Analytics workspace to retrieve Microsoft Graph API activity
    for each application over a specified time period using parallel runspace execution.

    Uses PSFramework's Runspace Workflow for efficient parallel processing while maintaining
    pipeline streaming capabilities. Applications are processed through a queue-based workflow
    with configurable parallelization.

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
    - Parallel processing using PSFramework runspaces (5-10x faster for large datasets)
    - Pipeline streaming for memory efficiency
    - Individual error handling (one failure doesn't stop processing)
    - Verbose logging for monitoring
    - Debug output for troubleshooting
    - Progress tracking
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
    Returns the input application objects enriched with an "Activity" property.

.EXAMPLE
    $apps | Get-AppActivityData -WorkspaceId $workspaceId -Days 90 -ThrottleLimit 20 -Verbose

    Queries activity data using the workspace ID (ByWorkspaceId parameter set).

.EXAMPLE
    $apps | Get-AppActivityData -subId $subscriptionId -rgName $resourceGroup -workspaceName $workspace -Days 30 -Verbose

    Queries activity data using workspace details (ByWorkspaceDetails parameter set) when using user_impersonation scope.

.NOTES
    Prerequisites:
    - PowerShell 5.1 or later
    - PSFramework module
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

        # Import PSFramework if not already loaded
        if (-not (Get-Module -Name PSFramework)) {
            Import-Module PSFramework -ErrorAction Stop
        }

        # Create unique workflow name
        $workflowName = "AppActivityWorkflow_$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $workflow = New-PSFRunspaceWorkflow -Name $workflowName

        $functions = @{
            'Get-AppActivityFromLog'           = (Get-Command 'Get-AppActivityFromLog').Definition
            'Convert-RelativeUriToAbsoluteUri' = (Get-Command 'Convert-RelativeUriToAbsoluteUri').Definition
            'ConvertTo-TokenizeId'             = (Get-Command 'ConvertTo-TokenizeId').Definition
        }

        # Variables to pass to runspaces - include parameter set specific values
        $variables = @{
            Days               = $Days
            MaxActivityEntries = $MaxActivityEntries
            logAnalyticsToken  = $logAnalyticsToken
            retainRawUri       = $retainRawUri
            ParameterSetName   = $PSCmdlet.ParameterSetName
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

        # Add the worker that processes apps
        $splatWorkflow = @{
            Name        = 'ActivityWorker'
            InQueue     = 'Input'
            OutQueue    = 'Output'
            Count       = $ThrottleLimit
            Variables   = $variables
            Functions   = $functions
            Modules     = 'EntraAuth', 'PSFramework'
            ScriptBlock = {
                param($AppObject)

                # Wrap everything in try-catch to ensure object is always returned
                try {
                    # Enable PSFramework message forwarding from runspace to parent session
                    $ExecutionContext.SessionState.PSVariable.Set("__PSFrameworkRunspaceParent__", $true)

                    # Re-import token in runspace
                    try {
                        Import-EntraToken -Token $logAnalyticsToken -NoRenew
                    }
                    catch {
                        # Use PSFramework's faster property addition (works in runspaces without loading PSFramework module)
                        try {
                            [PSFramework.Object.ObjectHost]::AddNoteProperty($AppObject, 'Activity', @())
                            [PSFramework.Object.ObjectHost]::AddNoteProperty($AppObject, 'ErrorMessage', "Auth failed: $($_.Exception.Message)")
                        }
                        catch {
                            # Fallback to Add-Member if PSFramework not available in runspace
                            $AppObject | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
                            $AppObject | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value "Auth failed: $($_.Exception.Message)" -Force
                        }
                        return $AppObject
                    }

                    # Get activity data - build parameters based on parameter set
                    try {
                        $activityParams = @{
                            days               = $Days
                            spId               = $AppObject.PrincipalId
                            maxActivityEntries = $MaxActivityEntries
                            retainRawUri       = $retainRawUri.IsPresent
                        }

                        if ($ParameterSetName -eq 'ByWorkspaceId') {
                            $activityParams['logAnalyticsWorkspace'] = $WorkspaceId
                        }
                        else {
                            $activityParams['subId'] = $subId
                            $activityParams['rgName'] = $rgName
                            $activityParams['workspaceName'] = $workspaceName
                        }

                        $activity = Get-AppActivityFromLog @activityParams

                        try {
                            [PSFramework.Object.ObjectHost]::AddNoteProperty($AppObject, 'Activity', $activity)
                        }
                        catch {
                            $AppObject | Add-Member -MemberType NoteProperty -Name "Activity" -Value $activity -Force
                        }
                    }
                    catch {
                        try {
                            [PSFramework.Object.ObjectHost]::AddNoteProperty($AppObject, 'Activity', @())
                            [PSFramework.Object.ObjectHost]::AddNoteProperty($AppObject, 'ErrorMessage', "Query failed: $($_.Exception.Message)")
                        }
                        catch {
                            $AppObject | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
                            $AppObject | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value "Query failed: $($_.Exception.Message)" -Force
                        }
                    }
                }
                catch {
                    try {
                        [PSFramework.Object.ObjectHost]::AddNoteProperty($AppObject, 'Activity', @())
                        [PSFramework.Object.ObjectHost]::AddNoteProperty($AppObject, 'ErrorMessage', "Unexpected error: $($_.Exception.Message)")
                    }
                    catch {
                        $AppObject | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
                        $AppObject | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value "Unexpected error: $($_.Exception.Message)" -Force
                    }
                }

                # Always return the object
                return $AppObject
            }
        }

        $workflow | Add-PSFRunspaceWorker @splatWorkflow | Out-Null

        $allApps = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($app in $AppData) {
            $allApps.Add($app)
        }
    }

    end {
        Write-PSFMessage -Level Verbose -Message "Processing $($allApps.Count) applications with $ThrottleLimit concurrent runspaces..."

        try {
            $workflow | Start-PSFRunspaceWorkflow

            $workflow | Write-PSFRunspaceQueue -Name 'Input' -BulkValues $allApps -Close

            # Collect results as they become available
            $results = [System.Collections.Generic.List[object]]::new()
            $lastProgressUpdate = [datetime]::Now
            $lastResultCount = 0
            $noProgressTimeout = [timespan]::FromMinutes(5)

            while ($results.Count -lt $allApps.Count) {
                # Read any available results
                $batch = $workflow | Read-PSFRunspaceQueue -Name 'Output'
                if ($batch) {
                    foreach ($item in $batch) {
                        $results.Add($item)
                    }

                    # If we get new results, reset the progress timer and show progress
                    if ($results.Count -gt $lastResultCount) {
                        $lastProgressUpdate = [datetime]::Now
                        $lastResultCount = $results.Count
                        Write-PSFMessage -Level Verbose -Message "Progress: $($results.Count)/$($allApps.Count) applications processed"
                    }
                }

                # Timeout check - only if truly no progress
                if (([datetime]::Now - $lastProgressUpdate) -gt $noProgressTimeout) {
                    Write-PSFMessage -Level Warning -Message "No progress for $($noProgressTimeout.TotalMinutes) minutes. Stopping workflow. Processed $($results.Count)/$($allApps.Count) applications."
                    break
                }

                Start-Sleep -Milliseconds 100
            }
        }
        finally {
            # Ensure cleanup happens
            try {
                $workflow | Stop-PSFRunspaceWorkflow
                $workflow | Remove-PSFRunspaceWorkflow
            }
            catch {
                Write-PSFMessage -Level Warning -Message "Error during workflow cleanup: $_"
            }
        }

        Write-PSFMessage -Level Verbose -Message "Completed processing: $($results.Count)/$($allApps.Count) applications."
        $enrichedCount = ($results | Where-Object { $_.Activity -and $_.Activity.Count -gt 0 }).Count
        $errorCount = ($results | Where-Object { $_.ErrorMessage }).Count

        if ($errorCount -gt 0) {
            Write-PSFMessage -Level Warning -Message "$errorCount applications had errors. Check objects with ErrorMessage property."
            # Show first few errors as examples
            $results | Where-Object { $_.ErrorMessage } | Select-Object -First 3 | ForEach-Object {
                Write-PSFMessage -Level Warning -Message "Example error - $($_.PrincipalName): $($_.ErrorMessage)"
            }
        }

        Write-PSFMessage -Level Verbose -Message "Successfully enriched $enrichedCount applications with activity data."

        $results
    }
}
