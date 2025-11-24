BeforeAll {
    $script:moduleName = 'LeastPrivilegedMSGraph'

    # Remove any existing module
    Get-Module $script:moduleName -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Try to import the module using the same pattern as QA tests
    $moduleInfo = Get-Module -Name $script:moduleName -ListAvailable | Select-Object -First 1

    if ($moduleInfo) {
        Import-Module -Name $script:moduleName -Force -ErrorAction Stop
        $script:moduleLoaded = $true
    }
    else {
        # Fallback: dot source the functions directly for testing
        # Load all private functions first
        $privateFunctions = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "*.ps1" -ErrorAction SilentlyContinue
        foreach ($func in $privateFunctions) {
            . $func.FullName
        }

        $publicFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Public" -Filter "Get-PermissionAnalysis.ps1" -ErrorAction SilentlyContinue

        if ($publicFunction) {
            . $publicFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find Get-PermissionAnalysis.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-PermissionAnalysis' {
    Context 'Parameter Validation' {
        It 'Should have mandatory AppData parameter' {
            $command = Get-Command -Name Get-PermissionAnalysis
            $command.Parameters['AppData'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should accept pipeline input for AppData' {
            $command = Get-Command -Name Get-PermissionAnalysis
            $command.Parameters['AppData'].Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command -Name Get-PermissionAnalysis
            $command.CmdletBinding | Should -Be $true
        }
    }

    Context 'Functionality' {
        BeforeAll {
            # Mock the helper functions
            if ($script:moduleLoaded) {
                Mock -CommandName Find-LeastPrivilegedPermissions -ModuleName $script:moduleName -MockWith {
                    return @{
                        Endpoint    = $Uri
                        Method      = $Method
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

                Mock -CommandName Get-OptimalPermissionSet -ModuleName $script:moduleName -MockWith {
                    return @(
                        @{
                            Permission        = 'User.ReadBasic.All'
                            ScopeType         = 'Application'
                            IsLeastPrivilege  = $true
                            ActivitiesCovered = 1
                        }
                    )
                }
            }
            else {
                Mock -CommandName Find-LeastPrivilegedPermissions -MockWith {
                    return @{
                        Endpoint    = $Uri
                        Method      = $Method
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

                Mock -CommandName Get-OptimalPermissionSet -MockWith {
                    return @(
                        @{
                            Permission        = 'User.ReadBasic.All'
                            ScopeType         = 'Application'
                            IsLeastPrivilege  = $true
                            ActivitiesCovered = 1
                        }
                    )
                }
            }
        }

        It 'Should process application data and add analysis properties' {
            $app = [PSCustomObject]@{
                PrincipalId   = 'test-id-001'
                PrincipalName = 'Test Application'
                AppRoleCount  = 1
                AppRoles      = @(
                    @{ FriendlyName = 'User.Read.All' }
                )
                Activity      = @(
                    @{
                        Method = 'GET'
                        Uri    = 'https://graph.microsoft.com/v1.0/users'
                    }
                )
            }

            $result = $app | Get-PermissionAnalysis
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should add ActivityPermissions property to output' {
            $app = [PSCustomObject]@{
                PrincipalId   = 'test-id-002'
                PrincipalName = 'Test Application 2'
                AppRoleCount  = 1
                AppRoles      = @(
                    @{ FriendlyName = 'User.Read.All' }
                )
                Activity      = @(
                    @{
                        Method = 'GET'
                        Uri    = 'https://graph.microsoft.com/v1.0/users'
                    }
                )
            }

            $result = $app | Get-PermissionAnalysis
            $result.PSObject.Properties.Name | Should -Contain 'ActivityPermissions'
        }

        It 'Should add OptimalPermissions property to output' {
            $app = [PSCustomObject]@{
                PrincipalId   = 'test-id-003'
                PrincipalName = 'Test Application 3'
                AppRoleCount  = 1
                AppRoles      = @(
                    @{ FriendlyName = 'User.Read.All' }
                )
                Activity      = @(
                    @{
                        Method = 'GET'
                        Uri    = 'https://graph.microsoft.com/v1.0/users'
                    }
                )
            }

            $result = $app | Get-PermissionAnalysis
            $result.PSObject.Properties.Name | Should -Contain 'OptimalPermissions'
        }

        It 'Should add CurrentPermissions property to output' {
            $app = [PSCustomObject]@{
                PrincipalId   = 'test-id-004'
                PrincipalName = 'Test Application 4'
                AppRoleCount  = 2
                AppRoles      = @(
                    @{ FriendlyName = 'User.Read.All' },
                    @{ FriendlyName = 'Directory.Read.All' }
                )
                Activity      = @(
                    @{
                        Method = 'GET'
                        Uri    = 'https://graph.microsoft.com/v1.0/users'
                    }
                )
            }

            $result = $app | Get-PermissionAnalysis
            $result.PSObject.Properties.Name | Should -Contain 'CurrentPermissions'
            $result.CurrentPermissions | Should -Contain 'User.Read.All'
            $result.CurrentPermissions | Should -Contain 'Directory.Read.All'
        }

        It 'Should add ExcessPermissions property to output' {
            $app = [PSCustomObject]@{
                PrincipalId   = 'test-id-005'
                PrincipalName = 'Test Application 5'
                AppRoleCount  = 1
                AppRoles      = @(
                    @{ FriendlyName = 'User.Read.All' }
                )
                Activity      = @(
                    @{
                        Method = 'GET'
                        Uri    = 'https://graph.microsoft.com/v1.0/users'
                    }
                )
            }

            $result = $app | Get-PermissionAnalysis
            $result.PSObject.Properties.Name | Should -Contain 'ExcessPermissions'
        }

        It 'Should add RequiredPermissions property to output' {
            $app = [PSCustomObject]@{
                PrincipalId   = 'test-id-006'
                PrincipalName = 'Test Application 6'
                AppRoleCount  = 1
                AppRoles      = @(
                    @{ FriendlyName = 'User.Read.All' }
                )
                Activity      = @(
                    @{
                        Method = 'GET'
                        Uri    = 'https://graph.microsoft.com/v1.0/users'
                    }
                )
            }

            $result = $app | Get-PermissionAnalysis
            $result.PSObject.Properties.Name | Should -Contain 'RequiredPermissions'
        }

        It 'Should preserve all original properties' {
            $app = [PSCustomObject]@{
                PrincipalId     = 'test-id-007'
                PrincipalName   = 'Test Application 7'
                AppRoleCount    = 1
                AppRoles        = @(
                    @{ FriendlyName = 'User.Read.All' }
                )
                Activity        = @(
                    @{
                        Method = 'GET'
                        Uri    = 'https://graph.microsoft.com/v1.0/users'
                    }
                )
                ThrottlingStats = @{ TotalRequests = 100 }
            }

            $result = $app | Get-PermissionAnalysis
            $result.PrincipalId | Should -Be 'test-id-007'
            $result.PrincipalName | Should -Be 'Test Application 7'
            $result.Activity | Should -Not -BeNullOrEmpty
            $result.ThrottlingStats | Should -Not -BeNullOrEmpty
        }
    }
}
