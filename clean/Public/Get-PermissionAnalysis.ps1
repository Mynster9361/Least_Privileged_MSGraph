function Get-PermissionAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [array]$AppData
    )
    
    begin {
        # Get the module root directory (goes up from Public folder)
        if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
            $moduleRoot = "."
        } else {
            $moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        
        # Construct paths to permission map files in the module root data folder
        $PermissionMapV1Path = Join-Path -Path $moduleRoot -ChildPath "data\permissions-v1.0.json"
        $PermissionMapBetaPath = Join-Path -Path $moduleRoot -ChildPath "data\permissions-beta.json"
        
        Write-Debug "Module root: $moduleRoot"
        Write-Debug "Loading permission maps..."
        Write-Debug "  V1.0 path: $PermissionMapV1Path"
        Write-Debug "  Beta path: $PermissionMapBetaPath"
        
        # Validate files exist
        if (-not (Test-Path -Path $PermissionMapV1Path)) {
            throw "Permission map file not found: $PermissionMapV1Path"
        }
        if (-not (Test-Path -Path $PermissionMapBetaPath)) {
            throw "Permission map file not found: $PermissionMapBetaPath"
        }
        
        $permissionMapv1 = Get-Content -Path $PermissionMapV1Path -Raw | ConvertFrom-Json
        $permissionMapbeta = Get-Content -Path $PermissionMapBetaPath -Raw | ConvertFrom-Json
        
        Write-Debug "Permission maps loaded successfully."
        
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