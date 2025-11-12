function Get-OptimalPermissionSet {
  param(
    [array]$activityPermissions
  )

  Write-Debug "Calculating optimal permission set..."

  # Check for unmatched activities
  $unmatchedActivities = $activityPermissions | Where-Object { -not $_.IsMatched }
  $matchedActivities = $activityPermissions | Where-Object { $_.IsMatched }

  if ($unmatchedActivities.Count -gt 0) {
    Write-Debug "Found $($unmatchedActivities.Count) activities without matches in permission map:"
    $unmatchedActivities | ForEach-Object {
      Write-Debug "  $($_.Method) $($_.Version)$($_.Path)"
    }
  }

  if ($matchedActivities.Count -eq 0) {
    return [PSCustomObject]@{
      OptimalPermissions  = @()
      UnmatchedActivities = $unmatchedActivities
      TotalActivities     = $activityPermissions.Count
      MatchedActivities   = 0
    }
  }

  # Collect all unique permissions across all activities
  $allPermissions = @{}

  foreach ($activity in $matchedActivities) {
    foreach ($perm in $activity.LeastPrivilegedPermissions) {
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
    if ($coveredActivities.Count -eq $matchedActivities.Count) {
      break
    }
  }

  return [PSCustomObject]@{
    OptimalPermissions  = $selectedPermissions
    UnmatchedActivities = $unmatchedActivities
    TotalActivities     = $activityPermissions.Count
    MatchedActivities   = $matchedActivities.Count
  }
}