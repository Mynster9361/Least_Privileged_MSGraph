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
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "Find-LeastPrivilegedPermissions.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
        else {
            throw "Could not find Find-LeastPrivilegedPermissions.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Find-LeastPrivilegedPermissions' {
    Context 'Parameter Validation' {
        It 'Should have mandatory Method parameter' {
            $command = Get-Command -Name Find-LeastPrivilegedPermissions
            $command.Parameters['Method'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have mandatory Uri parameter' {
            $command = Get-Command -Name Find-LeastPrivilegedPermissions
            $command.Parameters['Uri'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have mandatory PermissionMap parameter' {
            $command = Get-Command -Name Find-LeastPrivilegedPermissions
            $command.Parameters['PermissionMap'].Attributes.Mandatory | Should -Be $true
        }
    }

    Context 'Functionality' {
        BeforeAll {
            # Create a mock permission map
            $script:mockPermissionMap = @(
                @{
                    Endpoint = '/users'
                    Method   = @{
                        GET = @{
                            Permissions = @(
                                @{
                                    Permission       = 'User.Read.All'
                                    ScopeType        = 'Application'
                                    IsLeastPrivilege = $false
                                },
                                @{
                                    Permission       = 'User.ReadBasic.All'
                                    ScopeType        = 'Application'
                                    IsLeastPrivilege = $true
                                }
                            )
                        }
                    }
                }
            )
        }

        It 'Should find permissions for endpoint' {
            $result = Find-LeastPrivilegedPermissions -Method 'GET' -Uri 'https://graph.microsoft.com/v1.0/users' -PermissionMap $mockPermissionMap
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return permission objects' {
            $result = Find-LeastPrivilegedPermissions -Method 'GET' -Uri 'https://graph.microsoft.com/v1.0/users' -PermissionMap $mockPermissionMap
            $result.Permissions | Should -Not -BeNullOrEmpty
        }

        It 'Should identify least privileged permissions' {
            $result = Find-LeastPrivilegedPermissions -Method 'GET' -Uri 'https://graph.microsoft.com/v1.0/users' -PermissionMap $mockPermissionMap
            $leastPrivileged = $result.Permissions | Where-Object { $_.IsLeastPrivilege -eq $true }
            $leastPrivileged | Should -Not -BeNullOrEmpty
        }
    }
}
