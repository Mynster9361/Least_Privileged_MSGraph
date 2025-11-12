function Get-AppActivityFromLogs {
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

  Write-Debug "Querying Log Analytics for app activity in the last $days days for service principal $spId..."

  $body = @{
    query            = 'MicrosoftGraphActivityLogs
| where ServicePrincipalId == "' + $spId + '"
| where RequestUri !in("https://graph.microsoft.com/beta/$batch","https://graph.microsoft.com/v1.0/$batch")
| where ResponseStatusCode == "200"
| where isnotempty(AppId) and isnotempty(RequestUri) and isnotempty(RequestMethod)
| extend CleanedRequestUri = iff(indexof(RequestUri, "?") != -1, substring(RequestUri, 0, indexof(RequestUri, "?")), RequestUri)
| extend CleanedRequestUri = replace_string(CleanedRequestUri, "https://", "HTTPSPLACEHOLDER://")
| extend CleanedRequestUri = replace_regex(CleanedRequestUri, "//+", "/")
| extend CleanedRequestUri = replace_string(CleanedRequestUri, "HTTPSPLACEHOLDER:/", "https://")
| project AppId, RequestMethod, CleanedRequestUri
| distinct AppId, RequestMethod, CleanedRequestUri
| summarize Activity = make_set(pack("Method", RequestMethod, "Uri", CleanedRequestUri)) by AppId'
    options          = @{
      truncationMaxSize = 67108864
    }
    maxRows          = 1001
    workspaceFilters = @{
      regions = @()
    }
  }

  try {
    # Use EntraService to make the request
    $response = Invoke-EntraRequest -Service "LogAnalytics" -Method POST -Path "/v1/workspaces/$logAnalyticsWorkspace/query?timespan=P$($days)D" -Body ($body | ConvertTo-Json -Depth 10)

    if ($response.tables -and $response.tables.Count -gt 0 -and $response.tables[0].rows -and $response.tables[0].rows.Count -gt 0) {
      $data = $response.tables[0].rows[0][1] | ConvertFrom-Json
      $activity = $data
      Write-Debug "Found $($activity.Count) API calls for service principal $spId."

      if ($retainRawUri) {
        return $activity
      }

      $activity = @()
      foreach ($entry in $data) {
        $processedUriObject = Convert-RelativeUriToAbsoluteUri -Uri $entry.Uri
        $tokenizedUri = ConvertTo-TokenizeIds -UriString $processedUriObject.Uri
        $activity += [PSCustomObject]@{
          Method = $entry.Method
          Uri    = $tokenizedUri
        }
      }

      return $activity | Select-Object -Unique Method, Uri
    }
    else {
      Write-Debug "No activity data found for service principal $spId."
      return @()
    }
  }
  catch {
    Write-Debug "Failed to query Log Analytics workspace. Error: $_"
    return $null
  }
}