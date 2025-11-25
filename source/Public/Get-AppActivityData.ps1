function Get-AppActivityData {
    <#
.SYNOPSIS
    Enriches application data with API activity information from Azure Log Analytics.

.DESCRIPTION
    This function queries Azure Log Analytics workspace to retrieve Microsoft Graph API activity
    for each application over a specified time period. It gets the activity data as a new property
    to each application object, enabling analysis of what API calls each application has made.

    The function processes applications in batches, displaying progress information, and handles
    errors gracefully by continuing to process remaining applications even if some queries fail.

    Activity data includes:
    - HTTP methods used (GET, POST, PUT, PATCH, DELETE)
    - API endpoints accessed
    - Request timestamps
    - Response codes

    This data is essential for determining the least privileged permissions needed, as it shows
    what Graph API operations the application actually performs.

.PARAMETER AppData
    An array of application objects to enrich with activity data. Each object should contain
    at minimum:
    - PrincipalId: The service principal ID of the application
    - PrincipalName: The application display name (for logging/progress)

    This parameter accepts pipeline input, allowing you to pipe application objects directly
    into the function.

.PARAMETER WorkspaceId
    The Azure Log Analytics workspace ID (GUID) where Microsoft Graph API sign-in logs are stored.
    This workspace must contain MicrosoftGraphActivityLogs table with application activity data.

    Example: "12345678-1234-1234-1234-123456789012"

.PARAMETER Days
    The number of days of historical activity to retrieve, counting back from the current date.
    Default: 30 days

    Recommended values:
    - 7 days: Quick analysis for active applications
    - 30 days: Standard monthly review
    - 90 days: Comprehensive quarterly analysis

.OUTPUTS
    Array
    Returns the input application objects enriched with an "Activity" property containing an
    array of API activity records. If no activity is found or an error occurs, the Activity
    property will be an empty array.

.EXAMPLE
    $apps = Get-MgServicePrincipal -Filter "appId eq '00000000-0000-0000-0000-000000000000'"
    $enrichedApps = $apps | Get-AppActivityData -WorkspaceId "12345678-abcd-efgh-ijkl-123456789012"

    Retrieves activity for a specific application over the default 30-day period.

.EXAMPLE
    $allApps = Get-MgServicePrincipal -All
    $appsWithActivity = $allApps | Get-AppActivityData -WorkspaceId $workspaceId -Days 90
    $activeApps = $appsWithActivity | Where-Object { $_.Activity.Count -gt 0 }

    Analyzes 90 days of activity for all service principals and filters to only those with activity.

.EXAMPLE
    $apps = Get-Content .\apps.json | ConvertFrom-Json
    $results = Get-AppActivityData -AppData $apps -WorkspaceId $workspaceId -Days 7 -Verbose
    $results | Export-Clixml .\enriched-apps.xml

    Loads applications from JSON, gets 7 days of activity with verbose output, and saves results.

.EXAMPLE
    $criticalApps = Get-MgServicePrincipal -Filter "tags/any(t:t eq 'Critical')"
    $criticalApps | Get-AppActivityData -WorkspaceId $workspaceId -Days 30 |
        ForEach-Object {
            if ($_.Activity.Count -eq 0) {
                Write-Warning "$($_.PrincipalName) has no recent activity!"
            }
        }

    Monitors critical applications for activity and alerts if any have been inactive.

.NOTES
    Prerequisites:
    - Azure Log Analytics workspace with MicrosoftGraphActivityLogs enabled
    - Appropriate permissions to query the Log Analytics workspace
    - Get-AppActivityFromLog function must be available

    Performance Considerations:
    - Processing time scales linearly with the number of applications
    - Each application requires a separate Log Analytics query
    - Large result sets may take several minutes to complete
    - Progress bar updates after each application is processed

    Error Handling:
    - Failures for individual applications are logged as warnings
    - Processing continues even if some queries fail
    - Failed applications receive an empty Activity array

    This function uses Write-Debug for detailed processing information, Write-Verbose for
    progress updates, and Write-Progress for visual feedback during long operations.
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
        Write-Debug "Starting to get app activity data from Log Analytics..."
        $allIncomingApps = [System.Collections.ArrayList]::new()
        $allProcessedApps = [System.Collections.ArrayList]::new()
    }

    process {
        # First collect all incoming apps to get total count
        foreach ($app in $AppData) {
            [void]$allIncomingApps.Add($app)
        }
    }

    end {
        $totalCount = $allIncomingApps.Count
        $currentIndex = 0

        Write-Verbose "Processing $totalCount applications..."

        foreach ($app in $allIncomingApps) {
            $currentIndex++
            $spId = $app.PrincipalId

            # Calculate percentage
            $percentComplete = [math]::Round(($currentIndex / $totalCount) * 100, 2)

            # Update progress bar
            $progressParams = @{
                Activity         = "Querying Log Analytics for Application Activity"
                Status           = "Processing $currentIndex of $totalCount applications"
                CurrentOperation = "$($app.PrincipalName) (ID: $spId)"
                PercentComplete  = $percentComplete
            }
            Write-Progress @progressParams

            Write-Debug "[$currentIndex/$totalCount] Querying activity for $($app.PrincipalName) ($spId)..."

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

            # Add to collection
            [void]$allProcessedApps.Add($app)
        }

        # Complete the progress bar
        Write-Progress -Activity "Querying Log Analytics for Application Activity" -Completed

        "Successfully processed $($allProcessedApps.Count) applications."

        return $allProcessedApps
    }
}
