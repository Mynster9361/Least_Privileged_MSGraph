<#
.SYNOPSIS
    Enriches application data with activity logs from Log Analytics workspace.

.DESCRIPTION
    Queries Log Analytics for API activity for each application and adds the activity
    data to the application objects.

.PARAMETER AppData
    Array of application objects with PrincipalId property.

.PARAMETER WorkspaceId
    Log Analytics workspace ID to query.

.PARAMETER Days
    Number of days to look back for activity data.

.EXAMPLE
    $lightweightGroups | Add-AppActivityData -WorkspaceId "de2847546-662b-856a-a917-ab0f956d0fa1" -Days 30
#>
function Add-AppActivityData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [array]$AppData,
        
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,
        
        [Parameter(Mandatory = $false)]
        [int]$Days = 30
    )
    
    begin {
        Write-Debug "Starting to add app activity data from Log Analytics..."
        $allProcessedApps = [System.Collections.ArrayList]::new()
    }
    
    process {
        foreach ($app in $AppData) {
            $spId = $app.PrincipalId
            Write-Debug "Querying activity for $($app.PrincipalName) ($spId)..."
            
            try {
                $activity = Get-AppActivityFromLogs -logAnalyticsWorkspace $WorkspaceId -days $Days -spId $spId
                
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
                Write-Debug "Error retrieving activity for $($app.PrincipalName): $_"
                $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
            }
            
            # Add to collection - use void to suppress output
            [void]$allProcessedApps.Add($app)
        }
    }
    
    end {
        Write-Debug "Processed $($allProcessedApps.Count) apps total."
        return $allProcessedApps
    }
}