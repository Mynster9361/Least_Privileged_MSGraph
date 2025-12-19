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
    - Implements retry logic with progressive time window reduction for large responses

    By default, URIs are tokenized for permission mapping. Use -retainRawUri to keep actual
    resource identifiers for auditing/debugging.

    If the response exceeds Log Analytics size limits (100MB), the function automatically:
    1. Splits the time range in half
    2. Queries each half separately
    3. Combines and deduplicates results
    4. Recursively splits further if needed

.PARAMETER logAnalyticsWorkspace
    Log Analytics workspace ID (GUID) containing MicrosoftGraphActivityLogs table.
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

.PARAMETER days
    Number of days of historical activity to retrieve (used in P{days}D timespan format).
    Valid range: 1-365 days.

.PARAMETER spId
    Service principal object ID to filter activity for.

.PARAMETER retainRawUri
    Optional switch. Returns cleaned but non-tokenized URIs when specified.
    Default behavior tokenizes URIs by replacing IDs with {id} placeholders.

.PARAMETER MaxActivityEntries
    The maximum number of activity entries to retrieve per application from Log Analytics.
    This limits the result set size to prevent excessive data retrieval and memory consumption.
    Default: 100000

    Recommended values:
    - **30000**: Conservative, faster queries
    - **100000**: Balanced (default)

.PARAMETER startDate
    Internal parameter for recursive calls. Starting date for the query window.

.PARAMETER endDate
    Internal parameter for recursive calls. Ending date for the query window.

.OUTPUTS
    Array of PSCustomObject with Method and Uri properties.
    - Empty array (@()): No activity found
    - $null: Query failed (check debug output)

.EXAMPLE
    # Used internally by Get-AppActivityData (ByWorkspaceId parameter set)
    $activity = Get-AppActivityFromLog -logAnalyticsWorkspace $workspaceId -days 30 -spId $spId

.EXAMPLE
    # Get raw URIs for debugging (ByWorkspaceId parameter set)
    $rawActivity = Get-AppActivityFromLog -logAnalyticsWorkspace $workspaceId -days 7 -spId $spId -retainRawUri

.EXAMPLE
    # Query using workspace details (ByWorkspaceDetails parameter set)
    $activity = Get-AppActivityFromLog -subId $subscriptionId -rgName $resourceGroup -workspaceName $workspace -days 30 -spId $spId

.NOTES
    This is a private module function not exported to users.

    Requirements:
    - Invoke-EntraRequest must be available
    - Convert-RelativeUriToAbsoluteUri and ConvertTo-TokenizeId functions
    - Appropriate Log Analytics permissions
    - MicrosoftGraphActivityLogs table with diagnostic logging enabled

    Query limits: Configurable via maxActivityEntries parameter (default 100,000), 100MB response size.
    Uses KQL summarization for efficiency and deduplicates at query level.
    Maximum supported by Log Analytics: 500,000 rows per query.

    Response Size Handling:
    - If response exceeds 100MB, automatically splits time range
    - Recursively queries smaller windows until data fits
    - Minimum split window: 1 day
    - Combines results and deduplicates across windows
#>
  [CmdletBinding(DefaultParameterSetName = 'ByWorkspaceId')]
  [OutputType([System.Object[]])]
  param(
    [Parameter(Mandatory = $true, ParameterSetName = 'ByWorkspaceId')]
    [ValidateNotNullOrEmpty()]
    [string]$logAnalyticsWorkspace,

    [Parameter(Mandatory = $true, ParameterSetName = 'ByWorkspaceDetails')]
    [ValidateNotNullOrEmpty()]
    [string]$subId,

    [Parameter(Mandatory = $true, ParameterSetName = 'ByWorkspaceDetails')]
    [ValidateNotNullOrEmpty()]
    [string]$rgName,

    [Parameter(Mandatory = $true, ParameterSetName = 'ByWorkspaceDetails')]
    [ValidateNotNullOrEmpty()]
    [string]$workspaceName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$spId,

    [Parameter(Mandatory = $true)]
    [int]$days,

    [Parameter(Mandatory = $false)]
    [switch]$retainRawUri,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 500000)]
    [int]$maxActivityEntries = 100000,

    [Parameter(Mandatory = $false)]
    [datetime]$startDate,

    [Parameter(Mandatory = $false)]
    [datetime]$endDate
  )

  # Calculate date range if not provided (initial call)
  if (-not $startDate) {
    $endDate = [datetime]::UtcNow
    $startDate = $endDate.AddDays(-$days)
    Write-PSFMessage -Level Verbose -Message "Querying Log Analytics for app activity from $($startDate.ToString('yyyy-MM-dd')) to $($endDate.ToString('yyyy-MM-dd')) for service principal $spId"
  }
  else {
    Write-PSFMessage -Level Debug -Message "Querying window: $($startDate.ToString('yyyy-MM-dd')) to $($endDate.ToString('yyyy-MM-dd'))"
  }

  # Build KQL query with date range filter
  $startDateStr = $startDate.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
  $endDateStr = $endDate.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

  $kqlQuery = @"
MicrosoftGraphActivityLogs
| where TimeGenerated >= datetime($startDateStr) and TimeGenerated <= datetime($endDateStr)
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
| take $maxActivityEntries
| summarize Activity = make_set(pack("Method", RequestMethod, "Uri", CleanedRequestUri)) by AppId
"@

  $body = @{
    query            = $kqlQuery
    options          = @{
      truncationMaxSize = 67108864
    }
    workspaceFilters = @{
      regions = @()
    }
  }

  try {
    if ($PSCmdlet.ParameterSetName -eq 'ByWorkspaceDetails') {
      $response = Invoke-EntraRequest -Service "LogAnalytics" -Method POST -Path "/v1/subscriptions/$subId/resourcegroups/$rgName/providers/microsoft.operationalinsights/workspaces/$workspaceName/query" -Body ($body | ConvertTo-Json -Depth 10)
    }
    else {
      $response = Invoke-EntraRequest -Service "LogAnalytics" -Method POST -Path "/v1/workspaces/$logAnalyticsWorkspace/query" -Body ($body | ConvertTo-Json -Depth 10)
    }

    # Check for valid response structure
    if (-not $response.tables -or $response.tables.Count -eq 0) {
      Write-PSFMessage -Level Debug -Message "No activity data found for service principal $spId in this time window"
      return @()
    }

    $firstTable = $response.tables[0]
    if (-not $firstTable.rows -or $firstTable.rows.Count -eq 0) {
      Write-PSFMessage -Level Debug -Message "No activity data found for service principal $spId in this time window"
      return @()
    }

    # Parse the activity data from the first row's second column
    $rawActivityJson = $firstTable.rows[0][1]
    $activityData = $rawActivityJson | ConvertFrom-Json

    Write-PSFMessage -Level Debug -Message "Found $($activityData.Count) unique API call(s) for service principal $spId in this window"

    # Return raw URIs if requested
    if ($retainRawUri) {
      Write-PSFMessage -Level Debug -Message "Returning raw activity data with unprocessed URIs"
      return $activityData
    }

    # Process and tokenize URIs
    $processedActivity = foreach ($entry in $activityData) {
      try {
        $processedUriObject = Convert-RelativeUriToAbsoluteUri -Uri $entry.Uri
        $tokenizedUri = ConvertTo-TokenizeId -UriString $processedUriObject.Uri

        [PSCustomObject]@{
          Method = $entry.Method
          Uri    = $tokenizedUri
        }
      }
      catch {
        Write-PSFMessage -Level Warning -Message "Failed to process URI '$($entry.Uri)': $($_.Exception.Message). Skipping this entry."
        # Skip this entry by not outputting anything
      }
    }

    # Return unique entries
    $uniqueActivity = $processedActivity | Sort-Object Method, Uri -Unique
    Write-PSFMessage -Level Debug -Message "Processed and deduplicated to $($uniqueActivity.Count) unique pattern(s) in this window"

    return $uniqueActivity
  }
  catch {
    # Check if error is due to response size
    $errorDetails = $null
    if ($_.ErrorDetails.Message) {
      try {
        $errorDetails = ($_.ErrorDetails.Message | ConvertFrom-Json).error
      }
      catch {
        # If we can't parse error details, treat as generic error
        Write-PSFMessage -Level Warning -Message "Error querying Log Analytics: $_"
        return $null
      }
    }

    # Handle ResponseSizeError by splitting the time range
    if ($errorDetails.code -eq 'ResponseSizeError') {
      $timeSpan = $endDate - $startDate

      # Don't split if we're already at 1 day or less
      if ($timeSpan.TotalDays -le 1) {
        Write-PSFMessage -Level Warning -Message "Response too large even for 1-day window. Service principal $spId has excessive activity. Actual size: $($errorDetails.message)"
        return @()
      }

      # Split the time range in half AND split the max entries to maintain the overall limit
      $midPoint = $startDate.AddDays($timeSpan.TotalDays / 2)
      $halfMaxEntries = [Math]::Max(1, [Math]::Floor($maxActivityEntries / 2))

      Write-PSFMessage -Level Warning -Message "Response size exceeded ($($errorDetails.message)). Splitting query into two windows with $halfMaxEntries entries each."
      Write-PSFMessage -Level Verbose -Message "Window 1: $($startDate.ToString('yyyy-MM-dd')) to $($midPoint.ToString('yyyy-MM-dd'))"
      Write-PSFMessage -Level Verbose -Message "Window 2: $($midPoint.ToString('yyyy-MM-dd')) to $($endDate.ToString('yyyy-MM-dd'))"

      # Query each half recursively with halved max entries
      # Build common parameters
      $recursiveParams = @{
        days               = $days
        spId               = $spId
        retainRawUri       = $retainRawUri
        maxActivityEntries = $halfMaxEntries
      }

      # Add parameter set specific parameters
      if ($PSCmdlet.ParameterSetName -eq 'ByWorkspaceId') {
        $recursiveParams['logAnalyticsWorkspace'] = $logAnalyticsWorkspace
      }
      else {
        $recursiveParams['subId'] = $subId
        $recursiveParams['rgName'] = $rgName
        $recursiveParams['workspaceName'] = $workspaceName
      }

      $firstHalf = Get-AppActivityFromLog @recursiveParams -startDate $startDate -endDate $midPoint
      $secondHalf = Get-AppActivityFromLog @recursiveParams -startDate $midPoint -endDate $endDate

      # Combine results
      $combinedActivity = @($firstHalf) + @($secondHalf)

      if ($combinedActivity.Count -eq 0) {
        return @()
      }

      # Deduplicate combined results
      $uniqueCombined = $combinedActivity | Sort-Object Method, Uri -Unique
      Write-PSFMessage -Level Verbose -Message "Combined and deduplicated to $($uniqueCombined.Count) unique pattern(s) across split windows"

      return $uniqueCombined
    }

    # For other errors, log and return null
    Write-PSFMessage -Level Warning -Message "Error querying Log Analytics for service principal $spId`: $($errorDetails.code) - $($errorDetails.message)"
    if ($errorDetails.innererror) {
      Write-PSFMessage -Level Debug -Message "Inner error: $($errorDetails.innererror | ConvertTo-Json -Depth 5)"
    }
    return $null
  }
}
