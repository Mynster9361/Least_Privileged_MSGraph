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

        It 'Should handle multiple activities' {
            $activityPermissions = @(
                @{
                    Endpoint    = '/users'
                    Method      = 'GET'
                    Permissions = @(
                        @{ Permission = 'User.ReadBasic.All'; ScopeType = 'Application'; IsLeastPrivilege = $true }
                    )
                },
                @{
                    Endpoint    = '/groups'
                    Method      = 'GET'
                    Permissions = @(
                        @{ Permission = 'Group.Read.All'; ScopeType = 'Application'; IsLeastPrivilege = $true }
                    )
                }
            )

            $result = Get-OptimalPermissionSet -ActivityPermissions $activityPermissions
            $result.Count | Should -Not -BeNullOrEmpty
        }
    }
}
