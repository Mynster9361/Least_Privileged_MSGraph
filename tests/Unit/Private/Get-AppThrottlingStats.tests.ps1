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
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "Get-AppThrottlingStats.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
        else {
            throw "Could not find Get-AppThrottlingStats.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AppThrottlingStats' {
    Context 'Parameter Validation' {
        It 'Should have mandatory WorkspaceId parameter' {
            $command = Get-Command -Name Get-AppThrottlingStats
            $command.Parameters['WorkspaceId'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have mandatory Days parameter' {
            $command = Get-Command -Name Get-AppThrottlingStats
            $command.Parameters['Days'].Attributes.Mandatory | Should -Be $true
        }
    }

    Context 'Functionality' {
        BeforeAll {
            # Mock Invoke-EntraRequest
            Mock -CommandName Invoke-EntraRequest -MockWith {
                return @{
                    tables = @(
                        @{
                            rows = @(
                                @('app-id-1', 1000, 950, 5, 40, 5, '2025-11-01T00:00:00Z', '2025-11-24T00:00:00Z'),
                                @('app-id-2', 500, 480, 0, 15, 5, '2025-11-01T00:00:00Z', '2025-11-24T00:00:00Z')
                            )
                        }
                    )
                }
            }
        }

        It 'Should return throttling statistics' {
            $result = Get-AppThrottlingStats -WorkspaceId 'test-workspace-id' -Days 30
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return dictionary with application IDs as keys' {
            $result = Get-AppThrottlingStats -WorkspaceId 'test-workspace-id' -Days 30
            $result.Keys | Should -Contain 'app-id-1'
            $result.Keys | Should -Contain 'app-id-2'
        }

        It 'Should include TotalRequests in stats' {
            $result = Get-AppThrottlingStats -WorkspaceId 'test-workspace-id' -Days 30
            $result['app-id-1'].TotalRequests | Should -Be 1000
        }

        It 'Should include SuccessfulRequests in stats' {
            $result = Get-AppThrottlingStats -WorkspaceId 'test-workspace-id' -Days 30
            $result['app-id-1'].SuccessfulRequests | Should -Be 950
        }

        It 'Should calculate ThrottleRate correctly' {
            $result = Get-AppThrottlingStats -WorkspaceId 'test-workspace-id' -Days 30
            $result['app-id-1'].ThrottleRate | Should -Be 0.5
        }

        It 'Should call Invoke-EntraRequest' {
            Get-AppThrottlingStats -WorkspaceId 'test-workspace-id' -Days 30
            Should -Invoke -CommandName Invoke-EntraRequest -Times 1 -Exactly
        }
    }
}
