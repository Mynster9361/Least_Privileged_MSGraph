function Find-LeastPrivilegedPermissions {
  <#
.SYNOPSIS
    Identifies the least privileged Microsoft Graph permissions required for specific API activities.

.DESCRIPTION
    This function analyzes user API activity against Microsoft Graph permission maps to determine
    the minimum set of permissions required. It matches API calls to their corresponding endpoints
    and extracts the least privileged application permissions needed for each activity.
    
    The function supports both v1.0 and beta API versions and normalizes URIs to handle dynamic
    segments like user IDs and email addresses. It prioritizes permissions explicitly marked as
    "least privileged" in the permission maps, falling back to all application-scoped permissions
    if none are specifically marked.

.PARAMETER userActivity
    An array of API activity objects containing Method and Uri properties.
    Each activity represents an API call made by an application.
    Example: @(@{Method='GET'; Uri='https://graph.microsoft.com/v1.0/users/me/messages'})

.PARAMETER permissionMapv1
    The permission mapping data for Microsoft Graph v1.0 API endpoints.
    Should contain endpoint definitions with their required permissions organized by HTTP method.

.PARAMETER permissionMapbeta
    The permission mapping data for Microsoft Graph beta API endpoints.
    Should contain endpoint definitions with their required permissions organized by HTTP method.

.OUTPUTS
    PSCustomObject[]
    Returns an array of objects for each activity with the following properties:
    - Method: The HTTP method used (GET, POST, PUT, PATCH, DELETE)
    - Version: The API version (v1.0 or beta)
    - Path: The normalized API path without the base URL
    - OriginalUri: The original complete URI from the activity
    - MatchedEndpoint: The matched endpoint pattern from the permission map (null if no match)
    - LeastPrivilegedPermissions: Array of permission objects with Permission, ScopeType, and IsLeastPrivilege properties
    - IsMatched: Boolean indicating whether a matching endpoint was found

.EXAMPLE
    $activities = @(
        @{Method='GET'; Uri='https://graph.microsoft.com/v1.0/users/me/messages'},
        @{Method='POST'; Uri='https://graph.microsoft.com/v1.0/users/me/sendMail'}
    )
    $results = Find-LeastPrivilegedPermissions -userActivity $activities -permissionMapv1 $v1Map -permissionMapbeta $betaMap
    
    Analyzes the activities and returns the least privileged permissions needed for reading messages and sending mail.

.EXAMPLE
    $results = Find-LeastPrivilegedPermissions -userActivity $appActivity -permissionMapv1 $v1Map -permissionMapbeta $betaMap
    $unmatchedActivities = $results | Where-Object { -not $_.IsMatched }
    
    Finds all activities that couldn't be matched to known endpoints, useful for identifying unsupported or custom APIs.

.EXAMPLE
    $results = Find-LeastPrivilegedPermissions -userActivity $activity -permissionMapv1 $v1Map -permissionMapbeta $betaMap
    $requiredPerms = $results.LeastPrivilegedPermissions.Permission | Select-Object -Unique
    
    Extracts a unique list of all permissions required across all activities.

.NOTES
    URI normalization rules:
    - GUIDs are replaced with {id} tokens for matching
    - Email addresses are replaced with {id} tokens
    - Paths are normalized to start with /
    
    Permission selection priority:
    1. Permissions marked with isLeastPrivilege = true and scopeType = Application
    2. All permissions with scopeType = Application (if no least privileged marked)
    
    This function uses Write-Debug for detailed processing information.
#>
  param(
    [array]$userActivity,
    [array]$permissionMapv1,
    [array]$permissionMapbeta
  )

  Write-Debug "Finding least privileged permissions for activities..."

  $results = @()

  foreach ($activity in $userActivity) {
    $method = $activity.Method
    $uri = $activity.Uri

    # Extract version and path
    $version = if ($uri -like "*https://graph.microsoft.com/v1.0*") {
      "v1.0"
    }
    elseif ($uri -like "*https://graph.microsoft.com/beta*") {
      "beta"
    }
    else {
      continue
    }

    $path = ($uri -split "https://graph.microsoft.com/$version")[1]
    if (-not $path) { continue }

    # Ensure path starts with /
    if (-not $path.StartsWith('/')) {
      $path = '/' + $path
    }

    # Choose correct permission map
    $permissionMap = if ($version -eq "v1.0") { $permissionMapv1 } else { $permissionMapbeta }

    # Find matching endpoint
    $matchedEndpoint = $null
    foreach ($endpoint in $permissionMap) {
      # Normalize paths for comparison
      $normalizedEndpoint = $endpoint.Endpoint -replace '\{[^}]+\}', '{id}'
      $normalizedPath = $path -replace '/[0-9a-fA-F-]{36}', '/{id}' -replace '/[^/]+@[^/]+', '/{id}'

      if ($normalizedPath -eq $normalizedEndpoint) {
        $matchedEndpoint = $endpoint
        break
      }
    }

    $leastPrivilegedPerms = @()

    if ($matchedEndpoint) {
      # Get permissions for this specific HTTP method
      if ($matchedEndpoint.Method.PSObject.Properties.Name -contains $method) {
        $methodPermissions = $matchedEndpoint.Method.$method

        # Filter to only least privileged permissions
        $leastPrivilegedPerms = $methodPermissions | Where-Object {
          $_.isLeastPrivilege -eq $true -and
          $_.scopeType -eq "Application"
        } | Select-Object -Property @{N = 'Permission'; E = { $_.value } }, @{N = 'ScopeType'; E = { $_.scopeType } }, @{N = 'IsLeastPrivilege'; E = { $_.isLeastPrivilege } }

        # If no least privileged marked, get all Application scope permissions
        if ($leastPrivilegedPerms.Count -eq 0) {
          $leastPrivilegedPerms = $methodPermissions | Where-Object {
            $_.scopeType -eq "Application"
          } | Select-Object -Property @{N = 'Permission'; E = { $_.value } }, @{N = 'ScopeType'; E = { $_.scopeType } }, @{N = 'IsLeastPrivilege'; E = { $_.isLeastPrivilege } }
        }
      }
    }

    $results += [PSCustomObject]@{
      Method                     = $method
      Version                    = $version
      Path                       = $path
      OriginalUri                = $uri
      MatchedEndpoint            = if ($matchedEndpoint) { $matchedEndpoint.Endpoint } else { $null }
      LeastPrivilegedPermissions = $leastPrivilegedPerms
      IsMatched                  = $null -ne $matchedEndpoint
    }
  }

  return $results
}