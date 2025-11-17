function Get-AppThrottlingStats {
    <#
    .SYNOPSIS
        Retrieves throttling statistics for applications from Log Analytics.
    
    .DESCRIPTION
        Queries Log Analytics for Microsoft Graph API throttling data including
        429 errors, request rates, and throttling patterns per service principal.
    
    .PARAMETER WorkspaceId
        Log Analytics workspace ID to query.
    
    .PARAMETER Days
        Number of days to look back for throttling data.
    
    .PARAMETER ServicePrincipalId
        Optional specific ServicePrincipalId to analyze. If not provided, analyzes all apps.
    
    .EXAMPLE
        Get-AppThrottlingStats -WorkspaceId "workspace-id" -Days 30
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,
        
        [Parameter(Mandatory = $false)]
        [int]$Days = 30,
        
        [Parameter(Mandatory = $false)]
        [string]$ServicePrincipalId
    )
    
    Write-Debug "Querying throttling statistics for last $Days days..."
    
    $spIdFilter = if ($ServicePrincipalId) { "| where ServicePrincipalId == '$ServicePrincipalId'" } else { "" }
    
    # Query groups by ServicePrincipalId instead of AppId
    $query = @"
MicrosoftGraphActivityLogs 
| where ServicePrincipalId != "" 
$spIdFilter
| summarize 
    TotalRequests = count(),
    Total429Errors = countif(ResponseStatusCode == 429),
    SuccessfulRequests = countif(ResponseStatusCode == 200),
    TotalClientErrors = countif(ResponseStatusCode >= 400 and ResponseStatusCode < 500),
    TotalServerErrors = countif(ResponseStatusCode >= 500),
    FirstOccurrence = min(TimeGenerated),
    LastOccurrence = max(TimeGenerated)
    by ServicePrincipalId, AppId
| extend 
    ThrottleRate = round((Total429Errors * 100.0) / TotalRequests, 2),
    ErrorRate = round(((TotalClientErrors + TotalServerErrors) * 100.0) / TotalRequests, 2),
    SuccessRate = round((SuccessfulRequests * 100.0) / TotalRequests, 2)
| extend
    ThrottlingSeverity = case(
        Total429Errors == long(0), 0,
        ThrottleRate >= 10.0, 4,
        ThrottleRate >= 5.0, 3,
        ThrottleRate >= 1.0, 2,
        1
    ),
    ThrottlingStatus = case(
        Total429Errors == long(0), "Normal",
        ThrottleRate >= 10.0, "Critical",
        ThrottleRate >= 5.0, "Warning",
        ThrottleRate >= 1.0, "Low",
        "Minimal"
    )
| project 
    ServicePrincipalId,
    AppId,
    TotalRequests,
    SuccessfulRequests,
    Total429Errors,
    TotalClientErrors,
    TotalServerErrors,
    ThrottleRate,
    ErrorRate,
    SuccessRate,
    ThrottlingSeverity,
    ThrottlingStatus,
    FirstOccurrence,
    LastOccurrence
"@
    
    $body = @{
        query            = $query
        options          = @{
            truncationMaxSize = 67108864
        }
        maxRows          = 10000
        workspaceFilters = @{
            regions = @()
        }
    }
    
    try {
        $response = Invoke-EntraRequest -Service "LogAnalytics" -Method POST `
            -Path "/v1/workspaces/$WorkspaceId/query?timespan=P$($Days)D" `
            -Body ($body | ConvertTo-Json -Depth 10)
        
        if ($response.tables -and $response.tables.Count -gt 0 -and $response.tables[0].rows) {
            $columns = $response.tables[0].columns.name
            $results = @()
            
            foreach ($row in $response.tables[0].rows) {
                $obj = [PSCustomObject]@{}
                for ($i = 0; $i -lt $columns.Count; $i++) {
                    $obj | Add-Member -MemberType NoteProperty -Name $columns[$i] -Value $row[$i]
                }
                $results += $obj
            }
            
            Write-Debug "Retrieved throttling stats for $($results.Count) service principals."
            return $results
        }
        else {
            Write-Debug "No throttling data found."
            return @()
        }
    }
    catch {
        Write-Warning "Failed to query throttling statistics. Error: $_"
        Write-Debug $_.Exception.Message
        return @()
    }
}