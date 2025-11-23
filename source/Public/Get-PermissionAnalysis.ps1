function Get-PermissionAnalysis {
    <#
.SYNOPSIS
    Analyzes application permissions against actual API activity to identify optimal permission sets.

.DESCRIPTION
    This function performs comprehensive permission analysis by comparing an application's current
    Microsoft Graph permissions against its actual API activity patterns. It determines the least
    privileged permission set needed and identifies excess or missing permissions.

    The function performs the following operations:
    1. Loads Microsoft Graph permission maps (v1.0 and beta endpoints)
    2. Analyzes each application's API activity to find required permissions
    3. Calculates the optimal (minimal) permission set using a greedy algorithm
    4. Compares current permissions against optimal permissions
    5. Identifies excess permissions that aren't needed
    6. Identifies missing permissions that should be added
    7. Tracks unmatched activities that couldn't be mapped to permissions

    This analysis is critical for implementing least privilege access principles and reducing
    security risks from over-privileged applications.

.PARAMETER AppData
    An array of application objects to analyze. Each object must contain:
    - PrincipalId: The service principal ID
    - PrincipalName: The application display name
    - Activity: Array of API activity objects with Method and Uri properties
    - AppRoles: Array of current app role assignments with FriendlyName property

    This parameter accepts pipeline input, enabling batch processing of multiple applications.

.OUTPUTS
    Array
    Returns the input application objects enriched with the following additional properties:
    - ActivityPermissions: Detailed permission mappings for each activity
    - OptimalPermissions: Array of optimal permission objects with Permission, ScopeType,
      IsLeastPrivilege, and ActivitiesCovered properties
    - UnmatchedActivities: Array of activities that couldn't be matched to known endpoints
    - CurrentPermissions: Array of currently assigned permission names
    - ExcessPermissions: Array of permissions assigned but not needed based on activity
    - RequiredPermissions: Array of permissions needed but not currently assigned
    - MatchedAllActivity: Boolean indicating if all activities were successfully matched

.EXAMPLE
    $apps = Get-MgServicePrincipal -All
    $appsWithActivity = $apps | Add-AppActivityData -WorkspaceId $workspaceId -Days 30
    $analysis = $appsWithActivity | Get-PermissionAnalysis

    Performs end-to-end analysis: retrieves apps, adds activity data, and analyzes permissions.

.EXAMPLE
    $analysis = Get-PermissionAnalysis -AppData $enrichedApps -Verbose
    $overPrivileged = $analysis | Where-Object { $_.ExcessPermissions.Count -gt 10 }
    $overPrivileged | Select-Object PrincipalName, @{N='Excess';E={$_.ExcessPermissions.Count}},
                                   @{N='Current';E={$_.CurrentPermissions.Count}},
                                   @{N='Optimal';E={$_.OptimalPermissions.Count}}

    Identifies applications with more than 10 excess permissions and displays comparison metrics.

.EXAMPLE
    $analysis = Get-PermissionAnalysis -AppData $apps
    $unmatched = $analysis | Where-Object { -not $_.MatchedAllActivity }

    foreach ($app in $unmatched) {
        Write-Host "`n$($app.PrincipalName) has unmatched activities:" -ForegroundColor Yellow
        $app.UnmatchedActivities | ForEach-Object {
            Write-Host "  $($_.Method) $($_.Path)" -ForegroundColor Gray
        }
    }

    Identifies applications with activities that couldn't be mapped to known permissions.

.EXAMPLE
    $analysis = Get-PermissionAnalysis -AppData $apps
    $needsUpdate = $analysis | Where-Object {
        $_.ExcessPermissions.Count -gt 0 -or $_.RequiredPermissions.Count -gt 0
    }

    $needsUpdate | ForEach-Object {
        [PSCustomObject]@{
            Application = $_.PrincipalName
            Status = if ($_.ExcessPermissions.Count -gt 0 -and $_.RequiredPermissions.Count -eq 0) {
                "Remove $($_.ExcessPermissions.Count) permissions"
            } elseif ($_.RequiredPermissions.Count -gt 0 -and $_.ExcessPermissions.Count -eq 0) {
                "Add $($_.RequiredPermissions.Count) permissions"
            } else {
                "Update ($($_.ExcessPermissions.Count) excess, $($_.RequiredPermissions.Count) missing)"
            }
            ExcessPerms = $_.ExcessPermissions -join ', '
            MissingPerms = $_.RequiredPermissions -join ', '
        }
    } | Format-Table -AutoSize

    Generates an actionable report showing which applications need permission updates.

.NOTES
    Prerequisites:
    - Permission map files must exist in the module's data folder:
      * data\permissions-v1.0.json
      * data\permissions-beta.json
    - Input applications must have Activity property populated (use Add-AppActivityData)
    - Input applications must have AppRoles property populated (use Get-AppRoleAssignments)

    Permission Maps:
    - Contains endpoint-to-permission mappings for Microsoft Graph APIs
    - Includes both v1.0 and beta API versions
    - Maps HTTP methods to required permissions
    - Indicates least privileged permissions with flags

    Analysis Algorithm:
    - Uses greedy set cover algorithm to minimize permission count
    - Prioritizes permissions marked as "least privileged"
    - Ensures all matched activities are covered by selected permissions
    - Tolerates unmatched activities (new or undocumented APIs)

    Performance Considerations:
    - Permission maps are loaded once in the begin block
    - Processing time scales linearly with number of applications
    - Each application is analyzed independently
    - Suitable for batch processing of many applications

    Output Properties:
    - All original app properties are preserved
    - New analysis properties are added via Add-Member
    - Use -Force to overwrite existing properties

    This function uses Write-Debug for detailed processing information and requires
    Find-LeastPrivilegedPermissions and Get-OptimalPermissionSet helper functions.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [array]$AppData
    )

    begin {
        $moduleRoot = $MyInvocation.MyCommand.Module.ModuleBase

        $PermissionMapV1Path = Join-Path -Path $moduleRoot -ChildPath "data\permissions-v1.0.json"
        $PermissionMapBetaPath = Join-Path -Path $moduleRoot -ChildPath "data\permissions-beta.json"

        Write-Debug "Module root: $moduleRoot"
        Write-Debug "Loading permission maps..."
        Write-Debug "V1 Path: $PermissionMapV1Path"
        Write-Debug "Beta Path: $PermissionMapBetaPath"

        # Validate files exist
        if (-not (Test-Path -Path $PermissionMapV1Path)) {
            throw "Permission map file not found: $PermissionMapV1Path"
        }
        if (-not (Test-Path -Path $PermissionMapBetaPath)) {
            throw "Permission map file not found: $PermissionMapBetaPath"
        }

        $permissionMapv1 = Get-Content -Path $PermissionMapV1Path -Raw | ConvertFrom-Json
        $permissionMapbeta = Get-Content -Path $PermissionMapBetaPath -Raw | ConvertFrom-Json

        Write-Debug "Permission maps loaded successfully"

        # Initialize collection for all processed apps
        $allProcessedApps = @()
    }


    process {
        foreach ($app in $AppData) {
            Write-Debug "`nAnalyzing: $($app.PrincipalName)"

            # Find least privileged permissions for each activity
            $splatLeastPrivileged = @{
                userActivity      = $app.Activity
                permissionMapv1   = $permissionMapv1
                permissionMapbeta = $permissionMapbeta
            }
            $activityPermissions = Find-LeastPrivilegedPermissions @splatLeastPrivileged

            # Get optimal permission set
            $optimalSet = Get-OptimalPermissionSet -activityPermissions $activityPermissions

            # Add results to app object
            $app | Add-Member -MemberType NoteProperty -Name "ActivityPermissions" -Value $activityPermissions -Force
            $app | Add-Member -MemberType NoteProperty -Name "OptimalPermissions" -Value $optimalSet.OptimalPermissions -Force
            $app | Add-Member -MemberType NoteProperty -Name "UnmatchedActivities" -Value $optimalSet.UnmatchedActivities -Force

            # Compare with current permissions
            $currentPermissions = $app.AppRoles | Select-Object -ExpandProperty FriendlyName | Where-Object { $_ -ne $null }
            $optimalPermissionNames = $optimalSet.OptimalPermissions | Select-Object -ExpandProperty Permission -Unique

            $excessPermissions = $currentPermissions | Where-Object { $optimalPermissionNames -notcontains $_ }
            $missingPermissions = $optimalPermissionNames | Where-Object { $currentPermissions -notcontains $_ }

            $app | Add-Member -MemberType NoteProperty -Name "CurrentPermissions" -Value $currentPermissions -Force
            $app | Add-Member -MemberType NoteProperty -Name "ExcessPermissions" -Value $excessPermissions -Force
            $app | Add-Member -MemberType NoteProperty -Name "RequiredPermissions" -Value $missingPermissions -Force

            if ($optimalSet.UnmatchedActivities) {
                $matchedAllActivity = $false
            }
            else {
                $matchedAllActivity = $true
            }
            $app | Add-Member -MemberType NoteProperty -Name "MatchedAllActivity" -Value $matchedAllActivity -Force

            # Display summary
            Write-Debug "  Matched Activities: $($optimalSet.MatchedActivities)/$($optimalSet.TotalActivities)"
            Write-Debug "  Optimal Permissions: $($optimalSet.OptimalPermissions.Count)"
            Write-Debug "  Current Permissions: $($currentPermissions.Count)"
            Write-Debug "  Excess Permissions: $($excessPermissions.Count)"

            $allProcessedApps += $app
        }
    }

    end {
        return $allProcessedApps
    }
}
