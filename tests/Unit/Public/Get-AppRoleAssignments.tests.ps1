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
        $publicFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Public" -Filter "Get-AppRoleAssignments.ps1" -ErrorAction SilentlyContinue

        if ($publicFunction) {
            . $publicFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find Get-AppRoleAssignments.ps1"
        }
    }
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
            # Mock differently based on whether module is loaded
            if ($script:moduleLoaded) {
                Mock -CommandName Invoke-EntraRequest -ModuleName $script:moduleName -MockWith {
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
                            }
                        )
                    }
                }

                Mock -CommandName Get-MgServicePrincipal -ModuleName $script:moduleName -MockWith {
                    return @{
                        AppRoles = @(
                            @{
                                Id    = '7ab1d382-f21e-4acd-a863-ba3e13f7da61'
                                Value = 'Directory.Read.All'
                            }
                        )
                    }
                }
            }
            else {
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
                            }
                        )
                    }
                }

                Mock -CommandName Get-MgServicePrincipal -MockWith {
                    return @{
                        AppRoles = @(
                            @{
                                Id    = '7ab1d382-f21e-4acd-a863-ba3e13f7da61'
                                Value = 'Directory.Read.All'
                            }
                        )
                    }
                }
            }
        }

        It 'Should return application role assignments' {
            $result = Get-AppRoleAssignments
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return objects with PrincipalId property' {
            $result = Get-AppRoleAssignments
            $result[0].PSObject.Properties.Name | Should -Contain 'PrincipalId'
        }

        It 'Should return objects with PrincipalName property' {
            $result = Get-AppRoleAssignments
            $result[0].PSObject.Properties.Name | Should -Contain 'PrincipalName'
        }

        It 'Should return objects with AppRoleCount property' {
            $result = Get-AppRoleAssignments
            $result[0].PSObject.Properties.Name | Should -Contain 'AppRoleCount'
        }

        It 'Should return objects with AppRoles property' {
            $result = Get-AppRoleAssignments
            $result[0].PSObject.Properties.Name | Should -Contain 'AppRoles'
        }

        It 'Should call Invoke-EntraRequest with correct parameters' {
            Get-AppRoleAssignments
            if ($script:moduleLoaded) {
                Should -Invoke -CommandName Invoke-EntraRequest -ModuleName $script:moduleName -Times 1 -Exactly
            }
            else {
                Should -Invoke -CommandName Invoke-EntraRequest -Times 1 -Exactly
            }
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}
