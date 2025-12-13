function Find-LeastPrivilegedPermission {
  <#
.SYNOPSIS
    Internal function to identify least privileged Microsoft Graph permissions for API activities.

.DESCRIPTION
    This private function analyzes API activity against Microsoft Graph permission maps to determine
    the minimum set of permissions required. Used internally by Get-PermissionAnalysis.

    The function:
    1. Normalizes URIs by replacing GUIDs and emails with {id} tokens
    2. Determines API version (v1.0 or beta) from URI
    3. Matches normalized paths to endpoints in permission maps
    4. Extracts permissions for the specific HTTP method
    5. Prioritizes permissions marked as "least privileged"

    Permission Selection Logic:
    - First priority: isLeastPrivilege = true AND scopeType = Application
    - Second priority: All Application scope permissions (if no least privileged marked)
    - Delegated permissions are excluded

.PARAMETER userActivity
    Array of activity objects with Method and Uri properties.
    Example: @{Method='GET'; Uri='https://graph.microsoft.com/v1.0/users/me/messages'}

.PARAMETER permissionMapv1
    Permission mapping data for v1.0 endpoints (array of endpoint objects with Method properties).

.PARAMETER permissionMapbeta
    Permission mapping data for beta endpoints (array of endpoint objects with Method properties).

.OUTPUTS
    PSCustomObject[]
    Array with properties: Method, Version, Path, OriginalUri, MatchedEndpoint,
    LeastPrivilegedPermissions, IsMatched

.EXAMPLE
    # Used internally by Get-PermissionAnalysis
    $results = Find-LeastPrivilegedPermission -userActivity $activity -permissionMapv1 $v1Map -permissionMapbeta $betaMap

.EXAMPLE
    # Check for unmatched endpoints
    $results = Find-LeastPrivilegedPermission -userActivity $activity -permissionMapv1 $v1Map -permissionMapbeta $betaMap
    $unmatched = $results | Where-Object { -not $_.IsMatched }

.NOTES
    This is a private module function not exported to users.

    Requirements:
    - Permission maps must match expected structure (Endpoint, Method properties)
    - Activity URIs must contain version segment (v1.0 or beta)
    - HTTP method must exist in the endpoint's Method object for permission extraction

    Normalization:
    - GUIDs (36-char) replaced with {id}
    - Email addresses (containing @) replaced with {id}
    - Paths normalized for exact matching (no fuzzy matching)

    Limitations:
    - Only returns Application scope permissions
    - Requires accurate permission map data
    - Custom/preview APIs may not be in permission maps

    Use -Debug to see URI normalization and endpoint matching details.

.LINK
    Get-PermissionAnalysis

.LINK
    Convert-RelativeUriToAbsoluteUri

.LINK
    ConvertTo-TokenizeId
#>
  param(
    [array]$userActivity,
    [array]$permissionMapv1,
    [array]$permissionMapbeta
  )

  Write-PSFMessage -Level Debug -Message  "Finding least privileged permissions for activities..."

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
    if (-not $path) {
      continue
    }

    # Ensure path starts with /
    if (-not $path.StartsWith('/')) {
      $path = '/' + $path
    }

    # Choose correct permission map
    $permissionMap = if ($version -eq "v1.0") {
      $permissionMapv1
    }
    else {
      $permissionMapbeta
    }

    # Find matching endpoint
    $null = $matchedEndpoint
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
      MatchedEndpoint            = if ($matchedEndpoint) {
        $matchedEndpoint.Endpoint
      }
      else {
        $null
      }
      LeastPrivilegedPermissions = $leastPrivilegedPerms
      IsMatched                  = $null -ne $matchedEndpoint
    }
  }

  return $results
}
