function Add-AppThrottlingData {
    <#
    .SYNOPSIS
        Enriches application data with throttling statistics.
    
    .DESCRIPTION
        Adds throttling metrics to application objects based on Log Analytics data.
        Apps without activity will have stats with zero values.
    
    .PARAMETER AppData
        Array of application objects with ServicePrincipal ID.
    
    .PARAMETER WorkspaceId
        Log Analytics workspace ID to query.
    
    .PARAMETER Days
        Number of days to look back for throttling data.
    
    .EXAMPLE
        $apps | Add-AppThrottlingData -WorkspaceId "workspace-id" -Days $daysToQuery
    #>
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
        Write-Verbose "Fetching throttling statistics for all applications..."
        $throttlingStats = Get-AppThrottlingStats -WorkspaceId $WorkspaceId -Days $Days
        
        Write-Host "Retrieved $($throttlingStats.Count) throttling stat records from Log Analytics" -ForegroundColor Cyan
        
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
            Write-Progress -Activity "Adding Throttling Statistics" `
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
            
            # Always add ThrottlingStats - either real data or zeroed out values
            if ($throttlingData) {
                $app | Add-Member -MemberType NoteProperty -Name "ThrottlingStats" -Value ([PSCustomObject]@{
                    TotalRequests           = $throttlingData.TotalRequests
                    SuccessfulRequests      = $throttlingData.SuccessfulRequests
                    Total429Errors          = $throttlingData.Total429Errors
                    TotalClientErrors       = $throttlingData.TotalClientErrors
                    TotalServerErrors       = $throttlingData.TotalServerErrors
                    ThrottleRate            = $throttlingData.ThrottleRate
                    ErrorRate               = $throttlingData.ErrorRate
                    SuccessRate             = $throttlingData.SuccessRate
                    ThrottlingSeverity      = $throttlingData.ThrottlingSeverity
                    ThrottlingStatus        = $throttlingData.ThrottlingStatus
                    FirstOccurrence         = $throttlingData.FirstOccurrence
                    LastOccurrence          = $throttlingData.LastOccurrence
                }) -Force
                
                Write-Debug "Added throttling stats for $($app.PrincipalName): Severity=$($throttlingData.ThrottlingSeverity), Status=$($throttlingData.ThrottlingStatus)"
            }
            else {
                # No activity found - add zeroed stats
                $app | Add-Member -MemberType NoteProperty -Name "ThrottlingStats" -Value ([PSCustomObject]@{
                    TotalRequests           = 0
                    SuccessfulRequests      = 0
                    Total429Errors          = 0
                    TotalClientErrors       = 0
                    TotalServerErrors       = 0
                    ThrottleRate            = 0
                    ErrorRate               = 0
                    SuccessRate             = 0
                    ThrottlingSeverity      = 0
                    ThrottlingStatus        = "No Activity"
                    FirstOccurrence         = $null
                    LastOccurrence          = $null
                }) -Force
                
                Write-Debug "No throttling data found for $($app.PrincipalName) (ServicePrincipalId: $spId) - added zero stats"
            }
            
            [void]$allProcessedApps.Add($app)
        }
    }
    
    end {
        Write-Progress -Activity "Adding Throttling Statistics" -Completed
        
        $matchedCount = ($allProcessedApps | Where-Object { 
            $_.ThrottlingStats -and $_.ThrottlingStats.TotalRequests -gt 0 
        }).Count
        
        Write-Host "Successfully processed $($allProcessedApps.Count) applications." -ForegroundColor Green
        Write-Host "  - Found throttling data for: $matchedCount applications" -ForegroundColor Cyan
        Write-Host "  - No activity for: $($allProcessedApps.Count - $matchedCount) applications" -ForegroundColor Yellow
        
        return $allProcessedApps
    }
}