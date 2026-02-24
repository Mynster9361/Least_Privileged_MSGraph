function Get-PermissionAnalysis {
    <#
.SYNOPSIS
    Enriches application data with permission analysis using MSGraphPermissions module.

.DESCRIPTION
    This function analyzes application permissions against actual API usage to determine
    the least privileged permission set required. It uses the Find-GraphLeastPrivilege
    cmdlet from the MSGraphPermissions module to perform accurate permission lookups.

    The permission scope (Application vs Delegated) is determined automatically from
    the activity data — each activity carries a Scheme property set by the Log Analytics
    query based on whether a ServicePrincipalId was present (Application) or not (Delegated).

    The function processes each application's activity and:
    1. Extracts API version and path from each activity URI
    2. Uses the activity's Scheme to query Find-GraphLeastPrivilege for the correct scope
    3. Calculates optimal permission set using greedy set cover algorithm
    4. Identifies excess permissions (granted but not needed) with scope-aware comparison
    5. Identifies missing permissions (needed but not granted)

    Permission Analysis includes:
    - **Activity Permissions**: Matched permissions for each API activity
    - **Optimal Permissions**: Minimum set covering all activities
    - **Current Permissions**: Currently granted application permissions
    - **Excess Permissions**: Granted but unused permissions
    - **Required Permissions**: Needed but missing permissions
    - **Unmatched Activities**: API calls without permission matches

.PARAMETER AppData
    Array of application objects with Activity and AppRoles properties.
    Typically from Get-AppRoleAssignment | Get-AppActivityData pipeline.

    Required Properties:
    - **PrincipalName** (String): Application display name
    - **Activity** (Array): API activity objects with Uri, Method, and Scheme properties
    - **AppRoles** (Array): Currently assigned Graph permissions

    Example application object:
    @{
        PrincipalName = "HR Application"
        PrincipalId = "12345678-1234-1234-1234-123456789012"
        Activity = @(@{Uri = "https://graph.microsoft.com/v1.0/users"; Method = "GET"; Scheme = "Application"})
        AppRoles = @(@{FriendlyName = "User.Read.All"; PermissionType = "Application"})
    }

.OUTPUTS
    PSCustomObject[]
    Returns input objects enriched with permission analysis properties:

    - **ActivityPermissions**: Array of matched permissions per activity
    - **OptimalPermissions**: Minimum permission set covering all activities
    - **UnmatchedActivities**: Activities without permission matches
    - **CurrentPermissions**: Currently granted permissions
    - **ExcessPermissions**: Granted but unused permissions
    - **RequiredPermissions**: Needed but missing permissions
    - **MatchedAllActivity**: Boolean indicating if all activities were matched

.EXAMPLE
    $apps = Get-AppRoleAssignment | Get-AppActivityData -WorkspaceId $workspaceId -Days 30
    $analysis = $apps | Get-PermissionAnalysis

    Description:
    Analyzes permissions for all applications based on 30 days of activity.
    The Scheme (Application/Delegated) is automatically determined from the activity data.

.EXAMPLE
    $analysis = $apps | Get-PermissionAnalysis
    $analysis | Where-Object { $_.ExcessPermissions.Count -gt 0 } |
        Select-Object PrincipalName, @{N='Excess';E={$_.ExcessPermissions -join ', '}}

    Description:
    Identifies applications with excessive permissions that can be removed.

.EXAMPLE
    $analysis = $apps | Get-PermissionAnalysis
    $analysis | Where-Object { -not $_.MatchedAllActivity } |
        ForEach-Object {
            Write-Warning "$($_.PrincipalName) has unmatched activities"
            $_.UnmatchedActivities | Format-Table Method, Path
        }

    Description:
    Finds applications with API activities that couldn't be matched to permissions.

.NOTES
    Prerequisites:
    - MSGraphPermissions module must be installed and imported
    - Get-OptimalPermissionSet function must be available (private function dependency)
    - PowerShell 5.1 or later
    - Application objects must have Activity property populated with Scheme

    Permission Matching:
    - Uses Find-GraphLeastPrivilege from MSGraphPermissions module
    - Extracts version (v1.0 or beta) from URI automatically
    - Scheme (Application/Delegated) is determined from the activity data
    - Handles both successful and unmatched activities gracefully

    Performance:
    - Calls Find-GraphLeastPrivilege once per unique activity (single scheme lookup)
    - Efficient permission set calculation using greedy algorithm
    - Typical processing: 1-5 seconds per application with 100-1000 activities

    Limitations:
    - Requires accurate activity data from Get-AppActivityData (with Scheme)
    - Custom/preview APIs may not have permission mappings
    - Unmatched activities don't fail the overall analysis

    Best Practices:
    - Collect sufficient activity data (30+ days recommended)
    - Review unmatched activities manually
    - Validate optimal permissions before applying changes
    - Use -Verbose for detailed matching information
    - Archive analysis results for compliance tracking

    Related Cmdlets:
    - Get-AppActivityData: Collect API activity from Log Analytics
    - Get-OptimalPermissionSet: Calculate minimum permission set (internal)
    - Find-GraphLeastPrivilege: MSGraphPermissions module cmdlet
    - Export-PermissionAnalysisReport: Generate visual reports

.LINK
    https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Get-PermissionAnalysis.html

.LINK
    https://github.com/merill/MSGraphPermissions
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowNull()]
        [array]$AppData
    )

    begin {
        Write-PSFMessage -Level Verbose -Message "Starting permission analysis using MSGraphPermissions module"

        # Verify MSGraphPermissions module is available
        if (-not (Get-Command -Name Find-GraphLeastPrivilege -ErrorAction SilentlyContinue)) {
            throw "Find-GraphLeastPrivilege cmdlet not found. Please install the MSGraphPermissions module: Install-Module MSGraphPermissions"
        }

        # Helper function to check if a permission is covered by existing permissions
        function Test-PermissionCoverage {
            param(
                [string]$RequiredPermission,
                [string]$RequiredScopeType,
                [array]$CurrentPermissions
            )

            # Helper to normalize scope types
            $normScope = {
                param([string]$s)
                if ($s -in @('DelegatedWork', 'DelegatedPersonal')) {
                    'Delegated'
                }
                else {
                    $s
                }
            }

            $requiredNorm = & $normScope $RequiredScopeType

            # Direct match (same permission name and scope type)
            $directMatch = $CurrentPermissions | Where-Object {
                $_.Permission -eq $RequiredPermission -and (& $normScope $_.ScopeType) -eq $requiredNorm
            }
            if ($directMatch) {
                return $true
            }

            # Application permissions can cover Delegated permission requirements
            if ($requiredNorm -eq 'Delegated') {
                $appPermission = $CurrentPermissions | Where-Object {
                    $_.Permission -eq $RequiredPermission -and (& $normScope $_.ScopeType) -eq 'Application'
                }
                if ($appPermission) {
                    Write-PSFMessage -Level Debug -Message "Permission $RequiredPermission (Delegated) is covered by Application scope"
                    return $true
                }
            }

            # Check for hierarchical coverage: ReadBasic < Read < ReadWrite
            # Build list of higher-level permissions that would cover the required one
            $higherPermissions = @()

            if ($RequiredPermission -match '^(.+)\.ReadBasic(\.All)?$') {
                # ReadBasic is covered by Read or ReadWrite (check with and without .All suffix)
                $baseScope = $Matches[1]
                $suffix = $Matches[2]
                $higherPermissions = @(
                    "$baseScope.Read",
                    "$baseScope.Read.All",
                    "$baseScope.ReadWrite",
                    "$baseScope.ReadWrite.All"
                )
                if ($suffix) {
                    $higherPermissions += "$baseScope.Read$suffix"
                    $higherPermissions += "$baseScope.ReadWrite$suffix"
                }
                $higherPermissions = $higherPermissions | Select-Object -Unique
            }
            elseif ($RequiredPermission -match '^(.+)\.Read(\.All)?$') {
                # Read is covered by ReadWrite (same suffix)
                $baseScope = $Matches[1]
                $suffix = $Matches[2]
                $higherPermissions = @("$baseScope.ReadWrite$suffix")
            }

            foreach ($higherPerm in $higherPermissions) {
                $higherMatch = $CurrentPermissions | Where-Object {
                    $_.Permission -eq $higherPerm -and (& $normScope $_.ScopeType) -eq $requiredNorm
                }
                if ($higherMatch) {
                    Write-PSFMessage -Level Debug -Message "Permission $RequiredPermission ($RequiredScopeType) is covered by $higherPerm (same scope)"
                    return $true
                }

                # Also check if Application scope covers Delegated requirement
                if ($requiredNorm -eq 'Delegated') {
                    $appHigher = $CurrentPermissions | Where-Object {
                        $_.Permission -eq $higherPerm -and (& $normScope $_.ScopeType) -eq 'Application'
                    }
                    if ($appHigher) {
                        Write-PSFMessage -Level Debug -Message "Permission $RequiredPermission (Delegated) is covered by $higherPerm (Application scope)"
                        return $true
                    }
                }
            }

            return $false
        }
    }

    process {
        # Handle null or empty input
        if ($null -eq $AppData -or $AppData.Count -eq 0) {
            Write-PSFMessage -Level Debug -Message "No app data provided in this pipeline iteration"
            return
        }

        foreach ($app in $AppData) {
            # Skip null or invalid entries
            if ($null -eq $app) {
                Write-PSFMessage -Level Debug -Message "Skipping null app entry"
                continue
            }

            Write-PSFMessage -Level Verbose -Message "Analyzing: $($app.PrincipalName)"

            # Handle apps without activity
            if ($null -eq $app.Activity -or $app.Activity.Count -eq 0) {
                Write-PSFMessage -Level Debug -Message "No activity found for $($app.PrincipalName)"

                $currentPermissions = if ($app.AppRoles) {
                    $app.AppRoles | Where-Object { $null -ne $_.FriendlyName } | ForEach-Object {
                        [PSCustomObject]@{
                            Permission = $_.FriendlyName
                            ScopeType  = $_.PermissionType
                        }
                    }
                }
                else {
                    @()
                }

                # Use individual AddNoteProperty for better compatibility
                [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'ActivityPermissions', @())
                [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'OptimalPermissions', @())
                [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'UnmatchedActivities', @())
                [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'CurrentPermissions', $currentPermissions)
                [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'ExcessPermissions', $currentPermissions)
                [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'RequiredPermissions', @())
                [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'MatchedAllActivity', $true)

                # Output the app immediately
                Write-Output $app
                continue
            }

            # Process each activity using Find-GraphLeastPrivilege
            $activityPermissions = @()

            foreach ($activity in $app.Activity) {
                try {
                    # Extract version and path from URI using regex split
                    $uriParts = $activity.Uri -split "https://graph\.microsoft\.com/(v1\.0|beta)"

                    if ($uriParts.Count -lt 3) {
                        Write-PSFMessage -Level Debug -Message "Could not parse URI: $($activity.Uri)"

                        # Add as unmatched activity
                        $activityPermissions += [PSCustomObject]@{
                            Method                     = $activity.Method
                            Version                    = $null
                            Path                       = $null
                            OriginalUri                = $activity.Uri
                            MatchedEndpoint            = $null
                            LeastPrivilegedPermissions = @()
                            IsMatched                  = $false
                        }
                        continue
                    }

                    $version = $uriParts[1]
                    $path = $uriParts[2]

                    # Determine the scheme from the activity data (set by Log Analytics query)
                    # Map "Application" → "Application", "Delegated" → "DelegatedWork" for Find-GraphLeastPrivilege
                    $activityScheme = if ($activity.Scheme -eq 'Delegated') {
                        'DelegatedWork'
                    }
                    else {
                        'Application'
                    }

                    # Map scheme to ScopeType for permission objects
                    $permScopeType = if ($activityScheme -eq 'Application') {
                        'Application'
                    }
                    else {
                        'Delegated'
                    }

                    Write-PSFMessage -Level Debug -Message "Querying $activityScheme permissions for: $($activity.Method) $path"

                    $schemePermissions = $null
                    try {
                        $schemePermissions = Find-GraphLeastPrivilege -Path $path -Method $activity.Method -Scheme $activityScheme
                    }
                    catch {
                        Write-PSFMessage -Level Debug -Message "Error querying $activityScheme permissions: $_"
                    }

                    if ($schemePermissions -and $schemePermissions.Count -gt 0) {
                        Write-PSFMessage -Level Debug -Message "Found $($schemePermissions.Count) $activityScheme permissions for $($activity.Method) $path"

                        $permissionObjects = $schemePermissions | ForEach-Object {
                            [PSCustomObject]@{
                                Permission       = $_.Permission
                                ScopeType        = $permScopeType
                                IsLeastPrivilege = $true
                            }
                        }

                        $activityPermissions += [PSCustomObject]@{
                            Method                     = $activity.Method
                            Version                    = $version
                            Path                       = $path
                            OriginalUri                = $activity.Uri
                            MatchedEndpoint            = $path
                            LeastPrivilegedPermissions = $permissionObjects
                            IsMatched                  = $true
                        }
                    }
                    else {
                        Write-PSFMessage -Level Debug -Message "No permissions found for: $($activity.Method) $path"

                        $activityPermissions += [PSCustomObject]@{
                            Method                     = $activity.Method
                            Version                    = $version
                            Path                       = $path
                            OriginalUri                = $activity.Uri
                            MatchedEndpoint            = $null
                            LeastPrivilegedPermissions = @()
                            IsMatched                  = $false
                        }
                    }
                }
                catch {
                    Write-PSFMessage -Level Warning -Message "Error processing activity $($activity.Method) $($activity.Uri): $_"

                    # Add as unmatched activity
                    $activityPermissions += [PSCustomObject]@{
                        Method                     = $activity.Method
                        Version                    = $null
                        Path                       = $null
                        OriginalUri                = $activity.Uri
                        MatchedEndpoint            = $null
                        LeastPrivilegedPermissions = @()
                        IsMatched                  = $false
                    }
                }
            }

            # Get current permissions - all types included since scope is determined per-activity
            $currentPermissions = if ($app.AppRoles) {
                $app.AppRoles | Where-Object { $null -ne $_.FriendlyName } | ForEach-Object {
                    [PSCustomObject]@{
                        Permission = $_.FriendlyName
                        ScopeType  = $_.PermissionType
                    }
                }
            }
            else {
                @()
            }

            Write-PSFMessage -Level Debug -Message "Current permissions: $($currentPermissions.Count)"

            # Get optimal permission set using greedy algorithm
            $optimalSet = Get-OptimalPermissionSet -activityPermissions $activityPermissions

            # Helper to normalize scope types for comparison (DelegatedWork/DelegatedPersonal → Delegated)
            $normScope = {
                param([string]$s)
                if ($s -in @('DelegatedWork', 'DelegatedPersonal')) {
                    'Delegated'
                }
                else {
                    $s
                }
            }

            # Find excess permissions (granted but not needed) - compare by both Permission name AND ScopeType
            $excessPermissions = $currentPermissions | Where-Object {
                $currentPerm = $_
                $currentNormScope = & $normScope $currentPerm.ScopeType
                -not ($optimalSet.OptimalPermissions | Where-Object {
                        $_.Permission -eq $currentPerm.Permission -and (& $normScope $_.ScopeType) -eq $currentNormScope
                    })
            }

            # Find missing permissions (needed but not granted) considering hierarchical coverage
            $missingPermissions = $optimalSet.OptimalPermissions | Where-Object {
                -not (Test-PermissionCoverage -RequiredPermission $_.Permission -RequiredScopeType $_.ScopeType -CurrentPermissions $currentPermissions)
            } | Select-Object Permission, ScopeType

            $matchedAllActivity = ($null -eq $app.Activity -or $app.Activity.Count -eq 0) -or
            ($null -eq $optimalSet.UnmatchedActivities -or $optimalSet.UnmatchedActivities.Count -eq 0)

            # Use individual AddNoteProperty calls
            [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'ActivityPermissions', $activityPermissions)
            [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'OptimalPermissions', $optimalSet.OptimalPermissions)
            [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'UnmatchedActivities', $optimalSet.UnmatchedActivities)
            [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'CurrentPermissions', $currentPermissions)
            [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'ExcessPermissions', $excessPermissions)
            [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'RequiredPermissions', $missingPermissions)
            [PSFramework.Object.ObjectHost]::AddNoteProperty($app, 'MatchedAllActivity', $matchedAllActivity)

            # Display summary
            $optimalCount = if ($optimalSet.OptimalPermissions.Count -gt 0) {
                ($optimalSet.OptimalPermissions | Select-Object -ExpandProperty Permission -Unique).Count
            }
            else {
                0
            }
            Write-PSFMessage -Level Verbose -Message "Analysis complete for $($app.PrincipalName): $optimalCount optimal permissions, $($excessPermissions.Count) excess, $($missingPermissions.Count) missing"
            Write-PSFMessage -Level Debug -Message "Matched: $($activityPermissions | Where-Object IsMatched | Measure-Object | Select-Object -ExpandProperty Count)/$($activityPermissions.Count) activities"

            # Output the app immediately to the pipeline
            Write-Output $app
        }
    }
}
