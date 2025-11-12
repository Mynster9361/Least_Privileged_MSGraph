function Find-LeastPrivilegedPermissions {
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