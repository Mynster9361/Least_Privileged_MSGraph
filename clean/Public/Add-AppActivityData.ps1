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
                Write-Warning "Error retrieving activity for $($app.PrincipalName): $_"
                $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
            }
            
            # Add to collection
            [void]$allProcessedApps.Add($app)
        }
        
        # Complete the progress bar
        Write-Progress -Activity "Querying Log Analytics for Application Activity" -Completed
        
        Write-Host "Successfully processed $($allProcessedApps.Count) applications." -ForegroundColor Green
        
        return $allProcessedApps
    }
}