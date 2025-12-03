function Get-AppActivityFromLog {
  <#
.SYNOPSIS
    Internal function to retrieve Microsoft Graph API activity from Azure Log Analytics.

.DESCRIPTION
    This private function queries Azure Log Analytics to extract API activity patterns for a given
    service principal. It's used internally by Get-AppActivityData and Get-PermissionAnalysis.

    The function:
    - Queries MicrosoftGraphActivityLogs for successful requests (HTTP 200)
    - Cleans URIs (removes query params, normalizes slashes)
    - Optionally tokenizes URIs (replaces IDs with {id} tokens)
    - Returns deduplicated Method/Uri combinations

    By default, URIs are tokenized for permission mapping. Use -retainRawUri to keep actual
    resource identifiers for auditing/debugging.

.PARAMETER logAnalyticsWorkspace
    Log Analytics workspace ID (GUID) containing MicrosoftGraphActivityLogs table.

.PARAMETER days
    Number of days of historical activity to retrieve (used in P{days}D timespan format).

.PARAMETER spId
    Service principal object ID to filter activity for.

.PARAMETER retainRawUri
    Optional switch. Returns cleaned but non-tokenized URIs when specified.
    Default behavior tokenizes URIs by replacing IDs with {id} placeholders.

.OUTPUTS
    Array of PSCustomObject with Method and Uri properties.
    - Empty array (@()): No activity found
    - $null: Query failed (check debug output)

.EXAMPLE
    # Used internally by Get-AppActivityData
    $activity = Get-AppActivityFromLog -logAnalyticsWorkspace $workspaceId -days 30 -spId $spId

.EXAMPLE
    # Get raw URIs for debugging
    $rawActivity = Get-AppActivityFromLog -logAnalyticsWorkspace $workspaceId -days 7 -spId $spId -retainRawUri

.NOTES
    This is a private module function not exported to users.

    Requirements:
    - Invoke-EntraRequest must be available
    - Convert-RelativeUriToAbsoluteUri and ConvertTo-TokenizeId functions
    - Appropriate Log Analytics permissions
    - MicrosoftGraphActivityLogs table with diagnostic logging enabled

    Query limits: 30,000 rows max, 64MB truncation size.
    Uses KQL summarization for efficiency and deduplicates at query level.
#>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$logAnalyticsWorkspace,

    [Parameter(Mandatory = $true)]
    [int]$days,

    [Parameter(Mandatory = $true)]
    [string]$spId,

    [Parameter(Mandatory = $false)]
    [switch]$retainRawUri
  )

  Write-PSFMessage -Level Verbose -Message "Querying Log Analytics for app activity in the last $days days for service principal $spId"

  # Use the actual spId parameter instead of hardcoded value
  $kqlQuery = @"
MicrosoftGraphActivityLogs
| where ServicePrincipalId == "$spId"
| where RequestUri !in("https://graph.microsoft.com/beta/`$batch","https://graph.microsoft.com/v1.0/`$batch")
| where ResponseStatusCode == "200"
| where isnotempty(AppId) and isnotempty(RequestUri) and isnotempty(RequestMethod)
| extend CleanedRequestUri = iff(indexof(RequestUri, "?") != -1, substring(RequestUri, 0, indexof(RequestUri, "?")), RequestUri)
| extend CleanedRequestUri = replace_string(CleanedRequestUri, "https://", "HTTPSPLACEHOLDER://")
| extend CleanedRequestUri = replace_regex(CleanedRequestUri, "//+", "/")
| extend CleanedRequestUri = replace_string(CleanedRequestUri, "HTTPSPLACEHOLDER:/", "https://")
| project AppId, RequestMethod, CleanedRequestUri
| distinct AppId, RequestMethod, CleanedRequestUri
| summarize Activity = make_set(pack("Method", RequestMethod, "Uri", CleanedRequestUri)) by AppId
"@

  $body = @{
    query            = $kqlQuery
    options          = @{
      truncationMaxSize = 67108864
    }
    maxRows          = 30000
    workspaceFilters = @{
      regions = @()
    }
  }

  try {
    $response = Invoke-EntraRequest -Service "LogAnalytics" -Method POST -Path "/v1/workspaces/$logAnalyticsWorkspace/query?timespan=P$($days)D" -Body ($body | ConvertTo-Json -Depth 10)

    # Check for valid response structure
    if (-not $response.tables -or $response.tables.Count -eq 0) {
      Write-PSFMessage -Level Verbose -Message "No activity data found for service principal $spId"
      return @()
    }

    $firstTable = $response.tables[0]
    if (-not $firstTable.rows -or $firstTable.rows.Count -eq 0) {
      Write-PSFMessage -Level Verbose -Message "No activity data found for service principal $spId"
      return @()
    }

    # Parse the activity data from the first row's second column
    $rawActivityJson = $firstTable.rows[0][1]
    $activityData = $rawActivityJson | ConvertFrom-Json

    Write-PSFMessage -Level Debug -Message "Found $($activityData.Count) unique API call(s) for service principal $spId"

    # Return raw URIs if requested
    if ($retainRawUri) {
      Write-PSFMessage -Level Debug -Message "Returning raw activity data with unprocessed URIs"
      return $activityData
    }

    # Process and tokenize URIs
    $processedActivity = foreach ($entry in $activityData) {
      Write-PSFMessage -Level Debug -Message "Processing: $($entry.Method) $($entry.Uri)"

      $processedUriObject = Convert-RelativeUriToAbsoluteUri -Uri $entry.Uri
      $tokenizedUri = ConvertTo-TokenizeId -UriString $processedUriObject.Uri

      [PSCustomObject]@{
        Method = $entry.Method
        Uri    = $tokenizedUri
      }
    }

    # Return unique entries
    $uniqueActivity = $processedActivity | Sort-Object Method, Uri -Unique
    Write-PSFMessage -Level Verbose -Message "Processed and deduplicated to $($uniqueActivity.Count) unique pattern(s)"

    return $uniqueActivity
  }
  catch {
    Write-PSFMessage -Level Error -Message "Failed to query Log Analytics workspace" -Exception $_.Exception
    return $null
  }
}
