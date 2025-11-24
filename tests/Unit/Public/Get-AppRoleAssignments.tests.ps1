BeforeAll {
    $script:moduleName = 'LeastPrivilegedMSGraph'

    # Remove any existing module
    Get-Module $script:moduleName -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Try to import the module using the same pattern as QA tests
    $moduleInfo = Get-Module -Name $script:moduleName -ListAvailable | Select-Object -First 1

    if ($moduleInfo) {
        Import-Module -Name $script:moduleName -Force -ErrorAction Stop
    }
    else {
        # Fallback: dot source the functions directly for testing
        $publicFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Public" -Filter "Get-AppRoleAssignments.ps1" -ErrorAction SilentlyContinue

        if ($publicFunction) {
            . $publicFunction.FullName
        }
        else {
            throw "Could not find Get-AppRoleAssignments.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AppRoleAssignments' {
    Context 'Parameter Validation' {
        It 'Should have no mandatory parameters' {
            $command = Get-Command -Name Get-AppRoleAssignments
            $mandatoryParams = $command.Parameters.Values | Where-Object { $_.Attributes.Mandatory -eq $true }
            $mandatoryParams | Should -BeNullOrEmpty
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command -Name Get-AppRoleAssignments
            $command.CmdletBinding | Should -Be $true
        }
    }

    Context 'Functionality' {
        BeforeAll {
            # Mock Invoke-EntraRequest to avoid actual API calls
            Mock -CommandName Invoke-EntraRequest -MockWith {
                return @{
                    value = @(
                        @{
                            id                 = 'sp-00000000-0000-0000-0000-000000000001'
                            displayName        = 'Test Application 1'
                            appRoleAssignments = @(
                                @{
                                    id                  = 'assignment-1'
                                    appRoleId           = '7ab1d382-f21e-4acd-a863-ba3e13f7da61'
                                    resourceId          = 'resource-1'
                                    resourceDisplayName = 'Microsoft Graph'
                                }
                            )
                        },
                        @{
                            id                 = 'sp-00000000-0000-0000-0000-000000000002'
                            displayName        = 'Test Application 2'
                            appRoleAssignments = @(
                                @{
                                    id                  = 'assignment-2'
                                    appRoleId           = 'df021288-bdef-4463-88db-98f22de89214'
                                    resourceId          = 'resource-1'
                                    resourceDisplayName = 'Microsoft Graph'
                                }
                            )
                        }
                    )
                }
            }

            # Mock Get-MgServicePrincipal for app role lookups
            Mock -CommandName Get-MgServicePrincipal -MockWith {
                return @{
                    AppRoles = @(
                        @{
                            Id    = '7ab1d382-f21e-4acd-a863-ba3e13f7da61'
                            Value = 'Directory.Read.All'
                        },
                        @{
                            Id    = 'df021288-bdef-4463-88db-98f22de89214'
                            Value = 'User.Read.All'
                        }
                    )
                }
            }
        }

        It 'Should return application role assignments' {
            $result = Get-AppRoleAssignments
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterThan 0
        }

        It 'Should return objects with PrincipalId property' {
            $result = Get-AppRoleAssignments
            $result[0].PSObject.Properties.Name | Should -Contain 'PrincipalId'
            $result[0].PrincipalId | Should -Not -BeNullOrEmpty
        }

        It 'Should return objects with PrincipalName property' {
            $result = Get-AppRoleAssignments
            $result[0].PSObject.Properties.Name | Should -Contain 'PrincipalName'
            $result[0].PrincipalName | Should -Not -BeNullOrEmpty
        }

        It 'Should return objects with AppRoleCount property' {
            $result = Get-AppRoleAssignments
            $result[0].PSObject.Properties.Name | Should -Contain 'AppRoleCount'
            $result[0].AppRoleCount | Should -BeGreaterThan 0
        }

        It 'Should return objects with AppRoles property' {
            $result = Get-AppRoleAssignments
            $result[0].PSObject.Properties.Name | Should -Contain 'AppRoles'
            $result[0].AppRoles | Should -Not -BeNullOrEmpty
        }

        It 'Should call Invoke-EntraRequest with correct parameters' {
            Get-AppRoleAssignments
            Should -Invoke -CommandName Invoke-EntraRequest -Times 1 -Exactly
        }
    }
}
