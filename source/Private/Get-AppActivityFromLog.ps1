function Get-AppActivityFromLog {
  <#
.SYNOPSIS
    Retrieves Microsoft Graph API activity for a specific service principal from Azure Log Analytics.

.DESCRIPTION
    This function queries Azure Log Analytics to extract API activity patterns for a given service
    principal over a specified time period. It retrieves successful API calls (HTTP 200 responses),
    cleans and normalizes the URIs, and optionally tokenizes them for permission mapping.

    The function performs the following operations:
    1. Queries MicrosoftGraphActivityLogs for the specified service principal
    2. Filters for successful requests (200 status code) with valid data
    3. Cleans URIs by removing query parameters and normalizing path separators
    4. Removes duplicate method/URI combinations
    5. Optionally tokenizes URIs by replacing IDs with {id} placeholders

    URI cleaning includes:
    - Removing query string parameters (everything after ?)
    - Normalizing multiple consecutive slashes to single slashes
    - Preserving the https:// scheme correctly

    The tokenization process (default behavior) replaces dynamic segments like user IDs, GUIDs,
    and email addresses with {id} tokens, making URIs suitable for permission mapping.

.PARAMETER logAnalyticsWorkspace
    The Azure Log Analytics workspace ID (GUID) where Microsoft Graph activity logs are stored.
    This workspace must contain the MicrosoftGraphActivityLogs table.

    Example: "12345678-1234-1234-1234-123456789012"

.PARAMETER days
    The number of days of historical activity to retrieve, counting back from the current date.
    Used to construct the KQL query timespan parameter.

    Example: 30 (retrieves last 30 days of activity)

.PARAMETER spId
    The service principal ID (object ID) of the application to query activity for.
    This is used to filter the MicrosoftGraphActivityLogs table.

    Example: "87654321-4321-4321-4321-210987654321"

.PARAMETER retainRawUri
    Optional switch parameter. When specified, returns URIs in their cleaned but non-tokenized form.
    By default, URIs are tokenized (IDs replaced with {id} placeholders) for permission mapping.

    Use this switch when you need to see the actual URIs called rather than the generalized patterns.

.OUTPUTS
    Array
    Returns an array of activity objects, each containing:
    - Method: The HTTP method used (GET, POST, PUT, PATCH, DELETE)
    - Uri: The API endpoint called (tokenized by default, raw if -retainRawUri is used)

    Returns an empty array (@()) if no activity is found.
    Returns $null if the query fails due to an error.

.EXAMPLE
    $activity = Get-AppActivityFromLog -logAnalyticsWorkspace "12345-workspace-id" -days 30 -spId "app-principal-id"

    Retrieves 30 days of tokenized activity for the specified service principal.
    Output example:
    Method Uri
    ------ ---
    GET    https://graph.microsoft.com/v1.0/users/{id}/messages
    POST   https://graph.microsoft.com/v1.0/users/{id}/sendMail

.EXAMPLE
    $rawActivity = Get-AppActivityFromLog -logAnalyticsWorkspace $workspaceId -days 7 -spId $spId -retainRawUri

    Retrieves 7 days of activity with actual URIs (not tokenized), useful for debugging or auditing.
    Output example:
    Method Uri
    ------ ---
    GET    https://graph.microsoft.com/v1.0/users/user@contoso.com/messages
    POST   https://graph.microsoft.com/v1.0/users/user@contoso.com/sendMail

.EXAMPLE
    $servicePrincipals | ForEach-Object {
        $activity = Get-AppActivityFromLog -logAnalyticsWorkspace $workspaceId -days 90 -spId $_.Id
        if ($activity.Count -gt 0) {
            [PSCustomObject]@{
                AppName = $_.DisplayName
                ApiCalls = $activity.Count
                Endpoints = ($activity.Uri | Select-Object -Unique).Count
            }
        }
    }

    Analyzes 90 days of activity for multiple applications and summarizes their API usage.

.EXAMPLE
    $activity = Get-AppActivityFromLog -logAnalyticsWorkspace $workspaceId -days 30 -spId $spId -Debug
    $activity | Group-Object Method | Select-Object Name, Count

    Retrieves activity with debug output and groups by HTTP method to see usage patterns.

.NOTES
    Prerequisites:
    - Azure Log Analytics workspace with MicrosoftGraphActivityLogs enabled
    - Appropriate permissions to query the workspace via Invoke-EntraRequest
    - Convert-RelativeUriToAbsoluteUri and ConvertTo-TokenizeId functions must be available

    Query Filtering:
    - Only includes responses with status code 200 (successful requests)
    - Excludes batch requests ($batch endpoints)
    - Requires AppId, RequestUri, and RequestMethod to be non-empty
    - Removes duplicates at the query level using distinct

    Performance Considerations:
    - Query uses KQL summarization for efficiency
    - Result set limited to 30000 rows maximum (maxRows parameter)
    - Truncation limit set to 64MB (truncationMaxSize parameter)

    Error Handling:
    - Returns $null if the Log Analytics query fails
    - Returns empty array if no activity is found
    - Uses Write-Debug for detailed processing information

    This function uses Invoke-EntraRequest to communicate with Log Analytics and requires
    the EntraService module or equivalent authentication mechanism.
#>
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
    maxRows          = 30000
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
        $tokenizedUri = ConvertTo-TokenizeId -UriString $processedUriObject.Uri
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
