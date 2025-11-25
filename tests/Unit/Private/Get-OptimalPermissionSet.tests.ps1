BeforeAll {
    $script:moduleName = 'LeastPrivilegedMSGraph'

    # Remove any existing module
    Get-Module $script:moduleName -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Try to import the module
    $moduleInfo = Get-Module -Name $script:moduleName -ListAvailable | Select-Object -First 1

    if ($moduleInfo) {
        Import-Module -Name $script:moduleName -Force -ErrorAction Stop
    }
    else {
        # Fallback: dot source the function directly for testing
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "Get-OptimalPermissionSet.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
        else {
            throw "Could not find Get-OptimalPermissionSet.ps1"
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
            $result.Count | Should -BeGreaterThan 0
        }
    }
}
