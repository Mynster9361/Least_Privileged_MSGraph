function Find-OverPrivilegedGraphApps {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,

        [Parameter(Mandatory = $true)]
        [string]$WorkspaceName,

        [int]$DaysToLookBack = 30,

        [string]$OutputFolder
    )

    # Check and create output folder if specified
    if ($OutputFolder -and -not (Test-Path -Path $OutputFolder)) {
        New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
    }

    # Load permission endpoint mappings - use a relative path with $PSScriptRoot for better portability
    $permissionEndpointsPath = "C:\Users\Morten\Desktop\github\Least_Privileged_MSGraph\graph_api_permissions_endpoints.json" #Join-Path -Path $PSScriptRoot -ChildPath "..\graph_api_permissions_endpoints.json"
    if (-not (Test-Path -Path $permissionEndpointsPath)) {
        $permissionEndpointsPath = "graph_api_permissions_endpoints.json"
    }

    $permissionEndpoints = Get-Content -Path $permissionEndpointsPath -Raw -ErrorAction Stop | ConvertFrom-Json

    # Verify the permissions data is valid
    if (-not $permissionEndpoints) {
        Write-Error "Failed to load permission endpoints data"
        return
    }

    # Create dynamic permission inference function
    function Get-InferredPermission {
        param (
            [string]$Method,
            [string]$Path
        )

        # Normalize path
        $normalizedPath = $Path.TrimStart('/').ToLower()
        if ([string]::IsNullOrEmpty($normalizedPath)) {
            return @()
        }

        # Extract the base resource type from the path
        $segments = $normalizedPath -split '/'
        if ($segments.Count -eq 0) {
            return @()
        }

        $resourceType = $segments[0]

        # Determine operation based on HTTP method
        # Following {resource}.{operation}.{constraint} pattern
        $operation = switch ($Method) {
            'GET' { 'Read' }
            { $_ -in 'POST', 'PUT', 'PATCH', 'DELETE' } { 'ReadWrite' }
            default { 'Read' }
        }

        # Default constraint is typically .All for API access
        $constraint = 'All'

        # Map resource segments to permission resources
        $permissionResource = switch ($resourceType) {
            'me' { 'User' }  # /me endpoints use User permissions
            'users' { 'User' }
            'groups' { 'Group' }
            'applications' { 'Application' }
            'servicePrincipals' { 'Application' }
            'organization' { 'Organization' }
            'directory' { 'Directory' }
            'directoryobjects' { 'Directory' }
            'identityGovernance' { 'IdentityGovernance' }
            'teams' { 'Team' }
            'sites' { 'Sites' }
            'security' { 'SecurityEvents' }
            'reports' { 'Reports' }
            'devices' { 'Device' }
            'drives' { 'Files' }
            'identity' { 'IdentityRiskEvent' }
            'communications' { 'Calls' }
            'policies' { 'Policy' }
            'subscriptions' { 'Subscription' }
            default { $null }  # Unknown resource type
        }

        # Special case handling for sub-resources
        if ($segments.Count -gt 1) {
            $subResource = $segments[1]

            # Photo permissions
            if ($normalizedPath -match 'photo|photos') {
                return @("ProfilePhoto.$operation.$constraint")
            }

            # Mail permissions
            elseif ($normalizedPath -match 'mail|messages|mailfolders') {
                return @("Mail.$operation.$constraint")
            }

            # Calendar permissions
            elseif ($normalizedPath -match 'events|calendar|calendars') {
                return @("Calendars.$operation.$constraint")
            }

            # Contacts permissions
            elseif ($normalizedPath -match 'contacts|contactfolders') {
                return @("Contacts.$operation.$constraint")
            }

            # Files permissions
            elseif ($normalizedPath -match 'drives|drive|files|onedrive') {
                return @("Files.$operation.$constraint")
            }

            # Member permissions
            elseif ($normalizedPath -match 'members|owners|memberof') {
                return @("Member.$operation.$constraint", "Directory.$operation.$constraint")
            }

            # AppRoleAssignments permissions
            elseif ($normalizedPath -match 'approleassignments') {
                return @("AppRoleAssignment.$operation.$constraint")
            }
        }

        # For root access to Microsoft Graph API
        if ($normalizedPath -match '^$|^v1\.0$|^beta$') {
            return @()
        }

        # Return the inferred permission if resource type was identified
        if ($permissionResource) {
            return @("$permissionResource.$operation.$constraint")
        }

        # Default handling for unknown resources
        # Try to create a reasonable permission name from the resource
        if ($resourceType) {
            $resourceName = (Get-Culture).TextInfo.ToTitleCase($resourceType)
            # Remove trailing 's' if present to match Microsoft's naming conventions
            if ($resourceName.EndsWith('s') -and $resourceName.Length -gt 1) {
                $resourceName = $resourceName.Substring(0, $resourceName.Length - 1)
            }
            return @("$resourceName.$operation.$constraint")
        }

        return @()
    }

    # Get all Graph API role assignments
    Write-Host "Getting Microsoft Graph role assignments..." -ForegroundColor Cyan
    $roleAssignments = Get-GraphRoleAssignments

    $results = @()
    $total = $roleAssignments.Count
    $current = 0

    foreach ($roleAssignment in $roleAssignments) {
        $current++
        Write-Progress -Activity "Analyzing Graph permissions" -Status "Processing $($roleAssignment.PrincipalDisplayName)" -PercentComplete (($current / $total) * 100)

        # Get usage data for this app/identity
        Write-Host "Analyzing $($roleAssignment.PrincipalDisplayName) ($current of $total)..." -ForegroundColor Green
        $usageData = Get-GraphPermissionUsage -RoleAssignment $roleAssignment -WorkspaceId $WorkspaceId -WorkspaceName $WorkspaceName -DaysToLookBack $DaysToLookBack

        # Track permissions usage
        $usedPermissions = @()
        $pathDetails = @()

        if ($usageData) {
            # Process each API call to determine required permissions
            foreach ($usage in $usageData) {
                $method = $usage.RequestMethod
                $path = $usage.NormalizedPath

                # 1. First try existing mapping from endpoints file
                $mappedPermissions = @()

                foreach ($permRole in $permissionEndpoints) {
                    # Skip if role has no endpoints defined
                    if (-not $permRole -or -not $permRole.Role -or -not $permRole.Endpoints) {
                        continue
                    }

                    foreach ($endpoint in $permRole.Endpoints) {
                        # Skip if endpoint doesn't have required properties
                        if (-not $endpoint -or -not $endpoint.Path -or -not $endpoint.Method) {
                            continue
                        }

                        # Normalize endpoint path for comparison
                        $endpointPath = $endpoint.Path -replace '{[^}]+}', '{id}'
                        $endpointPath = $endpointPath.TrimStart('/')

                        # Safe comparison that avoids null reference exceptions
                        $pathMatches = $false
                        if ($null -ne $path -and $null -ne $endpointPath) {
                            if ($path -eq $endpointPath) {
                                $pathMatches = $true
                            }
                            elseif ($path -and $path.GetType().Name -eq "String" -and $path.StartsWith($endpointPath)) {
                                $pathMatches = $true
                            }
                        }

                        if ($pathMatches -and $endpoint.Method -eq $method) {
                            $mappedPermissions += $permRole.Role
                        }
                    }
                }

                # 2. If no mapped permissions found, try dynamic inference
                $inferredPermissions = @()
                if ($mappedPermissions.Count -eq 0) {
                    $inferredPermissions = Get-InferredPermission -Method $method -Path $path
                }

                # Combine both permission sources
                $requiredPerms = @()

                # Add mapped permissions first
                foreach ($perm in $mappedPermissions) {
                    if ($perm -notin $requiredPerms) {
                        $requiredPerms += $perm
                    }
                }

                # Add inferred permissions if needed
                if ($requiredPerms.Count -eq 0) {
                    foreach ($perm in $inferredPermissions) {
                        if ($perm -notin $requiredPerms) {
                            $requiredPerms += $perm
                        }
                    }
                }

                # Add permissions to the used list
                foreach ($perm in $requiredPerms) {
                    if ($perm -notin $usedPermissions) {
                        $usedPermissions += $perm
                    }
                }

                # Add to path details
                $pathDetails += [PSCustomObject]@{
                    Method = $method
                    Path = $path
                    Count = $usage.RequestCount
                    LastAccess = $usage.LastAccess
                    RequiredPermissions = if ($requiredPerms) { $requiredPerms -join ", " } else { "Unknown" }
                    StatusCodes = $usage.StatusCodes -join ", "
                    IsMapped = ($mappedPermissions.Count -gt 0)
                    IsInferred = ($inferredPermissions.Count -gt 0)
                }
            }
        }

        # Find unused permissions
        $assignedPermissions = $roleAssignment.Permissions.Value
        $unusedPermissions = $assignedPermissions | Where-Object { $_ -notin $usedPermissions }

        # Store results
        $result = [PSCustomObject]@{
            AppName = $roleAssignment.PrincipalDisplayName
            Type = $roleAssignment.PrincipalType
            ObjectId = $roleAssignment.PrincipalId
            AssignedPermissions = $assignedPermissions
            UsedPermissions = $usedPermissions
            UnusedPermissions = $unusedPermissions
            TotalApiCalls = if ($usageData) { ($usageData | Measure-Object -Property RequestCount -Sum).Sum } else { 0 }
            ApiPathsCount = if ($usageData) { $usageData.Count } else { 0 }
            NoActivityFound = ($null -eq $usageData -or $usageData.Count -eq 0)
            PathDetails = $pathDetails
        }

        $results += $result

        # Generate per-app detailed report if output folder specified
        if ($OutputFolder) {
            $appReportFile = Join-Path -Path $OutputFolder -ChildPath "$($result.AppName -replace '[\\\/\:\*\?\"\<\>\|]', '_').csv"
            $pathDetails | Export-Csv -Path $appReportFile -NoTypeInformation
        }
    }

    Write-Progress -Activity "Analyzing Graph permissions" -Completed

    # Sort results by number of unused permissions (descending)
    $sortedResults = $results | Sort-Object -Property { $_.UnusedPermissions.Count } -Descending

    # Generate summary report
    if ($OutputFolder) {
        $summaryFile = Join-Path -Path $OutputFolder -ChildPath "PermissionUsageSummary.csv"

        $sortedResults | Select-Object AppName, Type,
                                     @{Name="AssignedPermissions";Expression={$_.AssignedPermissions -join ", "}},
                                     @{Name="UsedPermissions";Expression={$_.UsedPermissions -join ", "}},
                                     @{Name="UnusedPermissions";Expression={$_.UnusedPermissions -join ", "}},
                                     TotalApiCalls, ApiPathsCount, NoActivityFound |
            Export-Csv -Path $summaryFile -NoTypeInformation

        Write-Host "Summary report saved to $summaryFile" -ForegroundColor Cyan

        # Generate recommendations file
        $recommendationsFile = Join-Path -Path $OutputFolder -ChildPath "PermissionRecommendations.txt"
        $recommendations = @()

        foreach ($app in ($sortedResults | Where-Object { $_.UnusedPermissions.Count -gt 0 })) {
            $recommendations += "Application: $($app.AppName)"
            $recommendations += "Type: $($app.Type)"
            $recommendations += "========================================="
            if ($app.NoActivityFound) {
                $recommendations += "WARNING: No API activity detected in the last $DaysToLookBack days."
                $recommendations += "Consider monitoring for a longer period before removing permissions."
            } else {
                $recommendations += "API Calls: $($app.TotalApiCalls) (across $($app.ApiPathsCount) unique paths)"
            }
            $recommendations += ""
            $recommendations += "ASSIGNED PERMISSIONS:"
            $recommendations += $app.AssignedPermissions | ForEach-Object { "  - $_" }
            $recommendations += ""
            if ($app.UsedPermissions.Count -gt 0) {
                $recommendations += "USED PERMISSIONS:"
                $recommendations += $app.UsedPermissions | ForEach-Object { "  - $_" }
                $recommendations += ""
            }
            $recommendations += "POTENTIALLY UNUSED PERMISSIONS:"
            $recommendations += $app.UnusedPermissions | ForEach-Object { "  - $_" }
            $recommendations += ""
            $recommendations += "RECOMMENDATION:"
            $recommendations += "Review and consider removing these unused permissions if they are not required for future functionality."
            $recommendations += "=========================================="
            $recommendations += ""
        }

        $recommendations | Out-File -FilePath $recommendationsFile -Encoding utf8
        Write-Host "Permission recommendations saved to $recommendationsFile" -ForegroundColor Cyan
    } else {
        # Display console summary
        $sortedResults | Select-Object AppName, Type,
                                     @{Name="Assigned";Expression={$_.AssignedPermissions.Count}},
                                     @{Name="Used";Expression={$_.UsedPermissions.Count}},
                                     @{Name="Unused";Expression={$_.UnusedPermissions.Count}},
                                     TotalApiCalls |
            Format-Table -AutoSize

        # Show detailed information for apps with unused permissions
        foreach ($app in ($sortedResults | Where-Object { $_.UnusedPermissions.Count -gt 0 })) {
            Write-Host "`n$($app.AppName) ($($app.Type))" -ForegroundColor Cyan
            if ($app.NoActivityFound) {
                Write-Host "  No API activity detected in the last $DaysToLookBack days" -ForegroundColor Yellow
            } else {
                Write-Host "  $($app.TotalApiCalls) API calls across $($app.ApiPathsCount) unique paths" -ForegroundColor Gray
            }
            Write-Host "  Unused permissions:" -ForegroundColor Red
            $app.UnusedPermissions | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
        }
    }

    return $sortedResults
}