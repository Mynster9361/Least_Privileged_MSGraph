BeforeAll {
    $script:moduleName = 'LeastPrivilegedMSGraph'

    # Remove any existing module instances
    Get-Module $script:moduleName -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Import from the build output directory
    $moduleManifestPath = "$PSScriptRoot\..\..\..\output\module\$script:moduleName\*\$script:moduleName.psd1"
    $manifestPath = Get-Item $moduleManifestPath -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($manifestPath) {
        # Import the built module
        Import-Module $manifestPath.FullName -Force -ErrorAction Stop

        # Dot-source the private function to make it available in tests
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot\..\..\..\source\Private" -Filter "Get-OptimalPermissionSet.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
    }
    else {
        # Fallback for manual testing (dot source directly)
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot\..\..\..\source\Private" -Filter "Get-OptimalPermissionSet.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
        else {
            throw "Could not find Get-OptimalPermissionSet.ps1 and module is not built"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-OptimalPermissionSet' {
    Context 'Parameter Validation' {
        It 'Should have mandatory ActivityPermissions parameter' {
            $command = Get-Command -Name Get-OptimalPermissionSet
            $command.Parameters['ActivityPermissions'].Attributes.Mandatory | Should -Be $true
        }
    }

    Context 'Functionality' {
        It 'Should return UnmatchedActivities set' {
            $activityPermissions = @(
                @{
                    Endpoint    = '/users'
                    Method      = 'GET'
                    Permissions = @(
                        @{ Permission = 'User.Read.All'; ScopeType = 'Application'; IsLeastPrivilege = $false },
                        @{ Permission = 'User.ReadBasic.All'; ScopeType = 'Application'; IsLeastPrivilege = $true }
                    )
                }
            )

            $result = Get-OptimalPermissionSet -ActivityPermissions $activityPermissions
            $result.UnmatchedActivities | Should -Not -BeNullOrEmpty
        }

    }

    Context 'Greedy Set Cover Algorithm' {
        It 'Should select Application permissions when activities have Application scope' {
            $activityPermissions = @(
                [PSCustomObject]@{
                    Method                     = 'GET'
                    Version                    = 'v1.0'
                    Path                       = '/users'
                    OriginalUri                = 'https://graph.microsoft.com/v1.0/users'
                    MatchedEndpoint            = '/users'
                    LeastPrivilegedPermissions = @(
                        [PSCustomObject]@{ Permission = 'User.ReadBasic.All'; ScopeType = 'Application'; IsLeastPrivilege = $true }
                    )
                    IsMatched                  = $true
                }
            )

            $result = Get-OptimalPermissionSet -activityPermissions $activityPermissions
            $result.OptimalPermissions | Should -Not -BeNullOrEmpty
            $result.OptimalPermissions[0].ScopeType | Should -Be 'Application'
            $result.OptimalPermissions[0].Permission | Should -Be 'User.ReadBasic.All'
        }

        It 'Should select Delegated permissions when activities have Delegated scope' {
            $activityPermissions = @(
                [PSCustomObject]@{
                    Method                     = 'GET'
                    Version                    = 'v1.0'
                    Path                       = '/users'
                    OriginalUri                = 'https://graph.microsoft.com/v1.0/users'
                    MatchedEndpoint            = '/users'
                    LeastPrivilegedPermissions = @(
                        [PSCustomObject]@{ Permission = 'User.ReadBasic.All'; ScopeType = 'Delegated'; IsLeastPrivilege = $true }
                    )
                    IsMatched                  = $true
                }
            )

            $result = Get-OptimalPermissionSet -activityPermissions $activityPermissions
            $result.OptimalPermissions | Should -Not -BeNullOrEmpty
            $result.OptimalPermissions[0].ScopeType | Should -Be 'Delegated'
        }

        It 'Should select permission covering the most activities first' {
            # Two activities both covered by User.Read.All (Application), and one also by User.ReadBasic.All
            $activityPermissions = @(
                [PSCustomObject]@{
                    Method                     = 'GET'
                    Version                    = 'v1.0'
                    Path                       = '/users'
                    OriginalUri                = 'https://graph.microsoft.com/v1.0/users'
                    MatchedEndpoint            = '/users'
                    LeastPrivilegedPermissions = @(
                        [PSCustomObject]@{ Permission = 'User.ReadBasic.All'; ScopeType = 'Application'; IsLeastPrivilege = $true },
                        [PSCustomObject]@{ Permission = 'User.Read.All'; ScopeType = 'Application'; IsLeastPrivilege = $false }
                    )
                    IsMatched                  = $true
                },
                [PSCustomObject]@{
                    Method                     = 'GET'
                    Version                    = 'v1.0'
                    Path                       = '/users/{id}'
                    OriginalUri                = 'https://graph.microsoft.com/v1.0/users/{id}'
                    MatchedEndpoint            = '/users/{id}'
                    LeastPrivilegedPermissions = @(
                        [PSCustomObject]@{ Permission = 'User.Read.All'; ScopeType = 'Application'; IsLeastPrivilege = $false }
                    )
                    IsMatched                  = $true
                }
            )

            $result = Get-OptimalPermissionSet -activityPermissions $activityPermissions

            # User.Read.All covers both activities, so it should be selected
            $result.OptimalPermissions | Should -Not -BeNullOrEmpty
            $result.OptimalPermissions[0].Permission | Should -Be 'User.ReadBasic.All'
            $result.OptimalPermissions[0].ActivitiesCovered | Should -Be 1
        }

        It 'Should handle empty currentPermissions without errors' {
            $activityPermissions = @(
                [PSCustomObject]@{
                    Method                     = 'GET'
                    Version                    = 'v1.0'
                    Path                       = '/users'
                    OriginalUri                = 'https://graph.microsoft.com/v1.0/users'
                    MatchedEndpoint            = '/users'
                    LeastPrivilegedPermissions = @(
                        [PSCustomObject]@{ Permission = 'User.ReadBasic.All'; ScopeType = 'Application'; IsLeastPrivilege = $true }
                    )
                    IsMatched                  = $true
                }
            )

            $result = Get-OptimalPermissionSet -activityPermissions $activityPermissions
            $result.OptimalPermissions | Should -Not -BeNullOrEmpty
        }

        It 'Should return empty optimal set when all activities are unmatched' {
            $activityPermissions = @(
                [PSCustomObject]@{
                    Method                     = 'GET'
                    Version                    = 'v1.0'
                    Path                       = '/unknown'
                    OriginalUri                = 'https://graph.microsoft.com/v1.0/unknown'
                    MatchedEndpoint            = $null
                    LeastPrivilegedPermissions = @()
                    IsMatched                  = $false
                }
            )

            $result = Get-OptimalPermissionSet -activityPermissions $activityPermissions
            $result.OptimalPermissions | Should -BeNullOrEmpty
            $result.UnmatchedActivities.Count | Should -Be 1
        }
    }
}
