function Get-OptimalPermissionSet {
  <#
.SYNOPSIS
    Internal function to calculate the optimal set of permissions covering all API activities.

.DESCRIPTION
    This private function implements a greedy set cover algorithm to determine the smallest set of
    Microsoft Graph permissions needed to cover all matched API activities. Used internally by
    Get-PermissionAnalysis and Export-PermissionAnalysisReport.

    The algorithm:
    1. Collects all unique permissions across activities
    2. Sorts permissions by coverage (most activities covered first)
    3. Greedily selects permissions that cover the most uncovered activities
    4. Continues until all matched activities are covered

    Tracks unmatched activities separately and provides coverage statistics.

.PARAMETER activityPermissions
    Array of activity objects from Find-LeastPrivilegedPermission.
    Expected properties: IsMatched, LeastPrivilegedPermissions, Method, Version, Path

.OUTPUTS
    PSCustomObject
    Object with properties:
    - OptimalPermissions: Array of permission objects with ActivitiesCovered count
    - UnmatchedActivities: Array of activities without endpoint matches
    - TotalActivities: Total count of analyzed activities
    - MatchedActivities: Count of successfully matched activities

.EXAMPLE
    # Used internally by Get-PermissionAnalysis
    $optimal = Get-OptimalPermissionSet -activityPermissions $activityPermissions

.EXAMPLE
    $optimal = Get-OptimalPermissionSet -activityPermissions $activities
    "Selected $($optimal.OptimalPermissions.Count) permissions covering $($optimal.MatchedActivities) activities"

.NOTES
    This is a private module function not exported to users.

    Algorithm: Greedy Set Cover
    - Time Complexity: O(n * m) where n = permissions, m = activities
    - Not guaranteed to find absolute minimum, but provides practical approximation
    - Prefers permissions marked as least privileged when coverage is equal

    Returns empty OptimalPermissions array if:
    - Input is null or empty
    - No activities have valid permission mappings
    - All activities are unmatched

    Uses Write-Debug for processing details. Run with -Debug to see selection logic.

.LINK
    Get-PermissionAnalysis

.LINK
    Find-LeastPrivilegedPermission
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
