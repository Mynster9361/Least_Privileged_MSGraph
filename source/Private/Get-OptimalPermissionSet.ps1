function Get-OptimalPermissionSet {
  <#
.SYNOPSIS
    Calculates the optimal set of permissions that cover all API activities with minimum overlap.

.DESCRIPTION
    This function implements a greedy set cover algorithm to determine the smallest set of Microsoft
    Graph permissions needed to cover all matched API activities. It prioritizes permissions that
    cover the most activities, ensuring minimal permission grants while maintaining full functionality.

    The function analyzes activity-to-permission mappings and identifies which permissions provide
    the broadest coverage. It tracks unmatched activities separately and provides detailed statistics
    about coverage effectiveness.

    The algorithm works by:
    1. Collecting all unique permissions across all activities
    2. Sorting permissions by the number of activities they cover
    3. Greedily selecting permissions that cover the most uncovered activities
    4. Continuing until all matched activities are covered

.PARAMETER activityPermissions
    An array of activity objects returned from Find-LeastPrivilegedPermission.
    Each object should contain:
    - IsMatched: Boolean indicating if the activity matched an endpoint
    - LeastPrivilegedPermissions: Array of permission objects
    - Method, Version, Path: Activity identification properties

.OUTPUTS
    PSCustomObject
    Returns an object with the following properties:
    - OptimalPermissions: Array of permission objects with Permission, ScopeType, IsLeastPrivilege,
      and ActivitiesCovered properties
    - UnmatchedActivities: Array of activities that couldn't be matched to endpoints
    - TotalActivities: Total count of all activities analyzed
    - MatchedActivities: Count of activities that were successfully matched

.EXAMPLE
    $activities = Find-LeastPrivilegedPermission -userActivity $signInLogs -permissionMapv1 $v1Map -permissionMapbeta $betaMap
    $optimal = Get-OptimalPermissionSet -activityPermissions $activities

    "Optimal permissions needed: $($optimal.OptimalPermissions.Count)"
    "Activities covered: $($optimal.MatchedActivities) of $($optimal.TotalActivities)"
    $optimal.OptimalPermissions | Format-Table Permission, ActivitiesCovered

.EXAMPLE
    $optimal = Get-OptimalPermissionSet -activityPermissions $activities

    # Check if all activities were matched
    if ($optimal.UnmatchedActivities.Count -gt 0) {
        Write-Warning "Found $($optimal.UnmatchedActivities.Count) unmatched activities"
        $optimal.UnmatchedActivities | ForEach-Object {
            "  $($_.Method) $($_.Version)$($_.Path)"
        }
    }

.EXAMPLE
    $optimal = Get-OptimalPermissionSet -activityPermissions $activities

    # Get just the permission names for easy comparison
    $permissionNames = $optimal.OptimalPermissions.Permission

    # Compare with current permissions
    $excessPerms = $currentPerms | Where-Object { $_ -notin $permissionNames }
    $missingPerms = $permissionNames | Where-Object { $_ -notin $currentPerms }

.NOTES
    Algorithm: Greedy Set Cover
    - Time Complexity: O(n * m) where n is permissions and m is activities
    - The algorithm is not guaranteed to find the absolute minimum set, but provides a practical
      approximation that balances coverage and permission count

    When multiple permissions cover the same activities, the algorithm prefers:
    1. Permissions marked as least privileged (IsLeastPrivilege = true)
    2. Permissions that cover the most activities

    This function uses Write-Debug for detailed processing information.
#>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [array]$activityPermissions
  )

  Write-Debug "Calculating optimal permission set..."

  # Handle null or empty input
  if ($null -eq $activityPermissions -or $activityPermissions.Count -eq 0) {
    Write-Debug "No activity permissions provided"
    return [PSCustomObject]@{
      OptimalPermissions  = @()
      UnmatchedActivities = @()
      TotalActivities     = 0
      MatchedActivities   = 0
    }
  }

  # Check for unmatched activities
  $unmatchedActivities = $activityPermissions | Where-Object { -not $_.IsMatched }
  $matchedActivities = $activityPermissions | Where-Object { $_.IsMatched }

  # Filter out activities with null or empty permission arrays
  $activitiesWithPermissions = $matchedActivities | Where-Object {
    $null -ne $_.LeastPrivilegedPermissions -and $_.LeastPrivilegedPermissions.Count -gt 0
  }

  # Add activities without permissions to unmatched
  $activitiesWithoutPermissions = $matchedActivities | Where-Object {
    $null -eq $_.LeastPrivilegedPermissions -or $_.LeastPrivilegedPermissions.Count -eq 0
  }

  if ($activitiesWithoutPermissions.Count -gt 0) {
    Write-Debug "Found $($activitiesWithoutPermissions.Count) matched activities without permission mappings"
    $unmatchedActivities = @($unmatchedActivities) + @($activitiesWithoutPermissions)
  }

  if ($unmatchedActivities.Count -gt 0) {
    Write-Debug "Found $($unmatchedActivities.Count) activities without complete matches:"
    $unmatchedActivities | ForEach-Object {
      Write-Debug "  $($_.Method) $($_.Version)$($_.Path)"
    }
  }

  if ($activitiesWithPermissions.Count -eq 0) {
    Write-Debug "No activities with valid permission mappings found"
    return [PSCustomObject]@{
      OptimalPermissions  = @()
      UnmatchedActivities = $unmatchedActivities
      TotalActivities     = $activityPermissions.Count
      MatchedActivities   = 0
    }
  }

  # Collect all unique permissions across all activities
  $allPermissions = @{}

  foreach ($activity in $activitiesWithPermissions) {
    foreach ($perm in $activity.LeastPrivilegedPermissions) {
      # Skip null permissions
      if ($null -eq $perm -or [string]::IsNullOrEmpty($perm.Permission)) {
        continue
      }

      $key = "$($perm.Permission)|$($perm.ScopeType)"

      if (-not $allPermissions.ContainsKey($key)) {
        $allPermissions[$key] = @{
          Permission       = $perm.Permission
          ScopeType        = $perm.ScopeType
          IsLeastPrivilege = $perm.IsLeastPrivilege
          Activities       = [System.Collections.Generic.List[object]]::new()
        }
      }

      $activityId = "$($activity.Method)|$($activity.Version)|$($activity.Path)"
      if ($allPermissions[$key].Activities -notcontains $activityId) {
        [void]$allPermissions[$key].Activities.Add($activityId)
      }
    }
  }

  # Check if we found any permissions
  if ($allPermissions.Count -eq 0) {
    Write-Debug "No valid permissions found in activities"
    return [PSCustomObject]@{
      OptimalPermissions  = @()
      UnmatchedActivities = $unmatchedActivities
      TotalActivities     = $activityPermissions.Count
      MatchedActivities   = 0
    }
  }

  # Convert to array and sort by coverage (most activities covered first)
  $sortedPermissions = $allPermissions.Values | Sort-Object { $_.Activities.Count } -Descending

  # Greedy set cover: pick permissions that cover the most activities
  $selectedPermissions = @()
  $coveredActivities = @{}

  foreach ($perm in $sortedPermissions) {
    # Check if this permission covers any new activities
    $newActivityCount = 0
    foreach ($activityId in $perm.Activities) {
      if (-not $coveredActivities.ContainsKey($activityId)) {
        $newActivityCount++
      }
    }

    if ($newActivityCount -gt 0) {
      # Add this permission
      $selectedPermissions += [PSCustomObject]@{
        Permission        = $perm.Permission
        ScopeType         = $perm.ScopeType
        IsLeastPrivilege  = $perm.IsLeastPrivilege
        ActivitiesCovered = $newActivityCount
      }

      # Mark activities as covered
      foreach ($activityId in $perm.Activities) {
        $coveredActivities[$activityId] = $true
      }
    }

    # Stop if all activities are covered
    if ($coveredActivities.Count -eq $activitiesWithPermissions.Count) {
      break
    }
  }

  Write-Debug "Selected $($selectedPermissions.Count) optimal permissions covering $($coveredActivities.Count) activities"

  return [PSCustomObject]@{
    OptimalPermissions  = $selectedPermissions
    UnmatchedActivities = $unmatchedActivities
    TotalActivities     = $activityPermissions.Count
    MatchedActivities   = $activitiesWithPermissions.Count
  }
}
