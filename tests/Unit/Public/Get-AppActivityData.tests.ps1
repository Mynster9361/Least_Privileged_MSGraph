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
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "Get-AppActivityFromLogs.ps1" -ErrorAction SilentlyContinue
        $publicFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Public" -Filter "Get-AppActivityData.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
        if ($publicFunction) {
            . $publicFunction.FullName
        }

        if (-not $publicFunction) {
            throw "Could not find Get-AppActivityData.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AppActivityData' {
    Context 'Parameter Validation' {
        It 'Should have mandatory WorkspaceId parameter' {
            $command = Get-Command -Name Get-AppActivityData
            $command.Parameters['WorkspaceId'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should accept pipeline input for AppData' {
            $command = Get-Command -Name Get-AppActivityData
            $command.Parameters['AppData'].Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have Days parameter with default value of 30' {
            $command = Get-Command -Name Get-AppActivityData
            $command.Parameters['Days'] | Should -Not -BeNullOrEmpty
        }

        It 'Should have mandatory AppData parameter' {
            $command = Get-Command -Name Get-AppActivityData
            $command.Parameters['AppData'].Attributes.Mandatory | Should -Be $true
        }
    }

    Context 'Functionality' {
        BeforeAll {
            # Mock Get-AppActivityFromLogs
            Mock -CommandName Get-AppActivityFromLogs -MockWith {
                return @(
                    @{
                        Method = 'GET'
                        Uri    = 'https://graph.microsoft.com/v1.0/users'
                    },
                    @{
                        Method = 'GET'
                        Uri    = 'https://graph.microsoft.com/v1.0/groups'
                    }
                )
            }
        }

        It 'Should process application data from pipeline' {
            $app = [PSCustomObject]@{
                PrincipalId   = 'test-id-001'
                PrincipalName = 'Test Application'
                AppRoleCount  = 2
                AppRoles      = @()
            }

            $result = $app | Get-AppActivityData -WorkspaceId 'test-workspace-id' -Days 30
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should add Activity property to output' {
            $app = [PSCustomObject]@{
                PrincipalId   = 'test-id-002'
                PrincipalName = 'Test Application 2'
                AppRoleCount  = 1
                AppRoles      = @()
            }

            $result = $app | Get-AppActivityData -WorkspaceId 'test-workspace-id' -Days 30
            $result.PSObject.Properties.Name | Should -Contain 'Activity'
        }

        It 'Should preserve original properties' {
            $app = [PSCustomObject]@{
                PrincipalId   = 'test-id-003'
                PrincipalName = 'Test Application 3'
                AppRoleCount  = 1
                AppRoles      = @()
            }

            $result = $app | Get-AppActivityData -WorkspaceId 'test-workspace-id' -Days 30
            $result.PrincipalId | Should -Be 'test-id-003'
            $result.PrincipalName | Should -Be 'Test Application 3'
            $result.AppRoleCount | Should -Be 1
        }

        It 'Should call Get-AppActivityFromLogs for each application' {
            $apps = @(
                [PSCustomObject]@{
                    PrincipalId   = 'test-id-004'
                    PrincipalName = 'Test Application 4'
                    AppRoleCount  = 1
                    AppRoles      = @()
                },
                [PSCustomObject]@{
                    PrincipalId   = 'test-id-005'
                    PrincipalName = 'Test Application 5'
                    AppRoleCount  = 1
                    AppRoles      = @()
                }
            )

            $apps | Get-AppActivityData -WorkspaceId 'test-workspace-id' -Days 30
            Should -Invoke -CommandName Get-AppActivityFromLogs -Times 2 -Exactly
        }

        It 'Should handle multiple applications in pipeline' {
            $apps = @(
                [PSCustomObject]@{
                    PrincipalId   = 'test-id-006'
                    PrincipalName = 'Test Application 6'
                    AppRoleCount  = 1
                    AppRoles      = @()
                },
                [PSCustomObject]@{
                    PrincipalId   = 'test-id-007'
                    PrincipalName = 'Test Application 7'
                    AppRoleCount  = 1
                    AppRoles      = @()
                }
            )

            $result = $apps | Get-AppActivityData -WorkspaceId 'test-workspace-id' -Days 30
            $result.Count | Should -Be 2
        }
    }
}
