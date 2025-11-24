BeforeAll {
    $script:moduleName = 'LeastPrivilegedMSGraph'

    # Remove any existing module
    Get-Module $script:moduleName -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Try to import the module
    $moduleInfo = Get-Module -Name $script:moduleName -ListAvailable | Select-Object -First 1

    if ($moduleInfo) {
        Import-Module -Name $script:moduleName -Force -ErrorAction Stop
        $script:moduleLoaded = $true
    }
    else {
        # Fallback: dot source the function directly for testing
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "Get-AppActivityFromLogs.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find Get-AppActivityFromLogs.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AppActivityFromLogs' {
    Context 'Parameter Validation' {
        It 'Should have mandatory WorkspaceId parameter' {
            $command = Get-Command -Name Get-AppActivityFromLogs
            $command.Parameters['WorkspaceId'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have mandatory PrincipalId parameter' {
            $command = Get-Command -Name Get-AppActivityFromLogs
            $command.Parameters['PrincipalId'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have Days parameter with default value' {
            $command = Get-Command -Name Get-AppActivityFromLogs
            $command.Parameters['Days'] | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Functionality' {
        BeforeAll {
            # Mock Invoke-EntraRequest
            if ($script:moduleLoaded) {
                Mock -CommandName Invoke-EntraRequest -ModuleName $script:moduleName -MockWith {
                    return @{
                        tables = @(
                            @{
                                rows = @(
                                    @('GET', 'https://graph.microsoft.com/v1.0/users', 50),
                                    @('POST', 'https://graph.microsoft.com/v1.0/groups', 25)
                                )
                            }
                        )
                    }
                }
            }
            else {
                Mock -CommandName Invoke-EntraRequest -MockWith {
                    return @{
                        tables = @(
                            @{
                                rows = @(
                                    @('GET', 'https://graph.microsoft.com/v1.0/users', 50),
                                    @('POST', 'https://graph.microsoft.com/v1.0/groups', 25)
                                )
                            }
                        )
                    }
                }
            }
        }

        It 'Should return activity data' {
            $result = Get-AppActivityFromLogs -WorkspaceId 'test-workspace-id' -PrincipalId 'test-principal-id' -Days 30
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return objects with Method property' {
            $result = Get-AppActivityFromLogs -WorkspaceId 'test-workspace-id' -PrincipalId 'test-principal-id' -Days 30
            $result[0].Method | Should -Not -BeNullOrEmpty
        }

        It 'Should return objects with Uri property' {
            $result = Get-AppActivityFromLogs -WorkspaceId 'test-workspace-id' -PrincipalId 'test-principal-id' -Days 30
            $result[0].Uri | Should -Not -BeNullOrEmpty
        }

        It 'Should call Invoke-EntraRequest' {
            Get-AppActivityFromLogs -WorkspaceId 'test-workspace-id' -PrincipalId 'test-principal-id' -Days 30
            if ($script:moduleLoaded) {
                Should -Invoke -CommandName Invoke-EntraRequest -ModuleName $script:moduleName -Times 1 -Exactly
            }
            else {
                Should -Invoke -CommandName Invoke-EntraRequest -Times 1 -Exactly
            }
        }
    }
}
