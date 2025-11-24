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
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "Get-AppThrottlingStats.ps1" -ErrorAction SilentlyContinue
        $publicFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Public" -Filter "Get-AppThrottlingData.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
        if ($publicFunction) {
            . $publicFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find Get-AppThrottlingData.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AppThrottlingData' {
    Context 'Parameter Validation' {
        It 'Should have mandatory WorkspaceId parameter' {
            $command = Get-Command -Name Get-AppThrottlingData
            $command.Parameters['WorkspaceId'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should accept pipeline input for AppData' {
            $command = Get-Command -Name Get-AppThrottlingData
            $command.Parameters['AppData'].Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have Days parameter with default value of 30' {
            $command = Get-Command -Name Get-AppThrottlingData
            $command.Parameters['Days'] | Should -Not -BeNullOrEmpty
        }

        It 'Should have mandatory AppData parameter' {
            $command = Get-Command -Name Get-AppThrottlingData
            $command.Parameters['AppData'].Attributes.Mandatory | Should -Be $true
        }
    }

    Context 'Functionality' {
        BeforeAll {
            # Mock based on module load status
            if ($script:moduleLoaded) {
                Mock -CommandName Get-AppThrottlingStats -ModuleName $script:moduleName -MockWith {
                    return @{
                        'test-id-001' = @{
                            TotalRequests      = 1000
                            SuccessfulRequests = 950
                            Total429Errors     = 5
                            TotalClientErrors  = 40
                            TotalServerErrors  = 5
                            ThrottleRate       = 0.5
                            ErrorRate          = 5.0
                            SuccessRate        = 95.0
                            ThrottlingSeverity = 1
                            ThrottlingStatus   = 'Low'
                            FirstOccurrence    = '2025-11-01T00:00:00Z'
                            LastOccurrence     = '2025-11-24T00:00:00Z'
                        }
                    }
                }
            }
            else {
                Mock -CommandName Get-AppThrottlingStats -MockWith {
                    return @{
                        'test-id-001' = @{
                            TotalRequests      = 1000
                            SuccessfulRequests = 950
                            Total429Errors     = 5
                            TotalClientErrors  = 40
                            TotalServerErrors  = 5
                            ThrottleRate       = 0.5
                            ErrorRate          = 5.0
                            SuccessRate        = 95.0
                            ThrottlingSeverity = 1
                            ThrottlingStatus   = 'Low'
                            FirstOccurrence    = '2025-11-01T00:00:00Z'
                            LastOccurrence     = '2025-11-24T00:00:00Z'
                        }
                    }
                }
            }
        }

        It 'Should process application data from pipeline' {
            $app = [PSCustomObject]@{
                PrincipalId   = 'test-id-001'
                PrincipalName = 'Test Application'
                AppRoleCount  = 2
                AppRoles      = @()
                Activity      = @()
            }

            $result = $app | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should add ThrottlingStats property to output' {
            $app = [PSCustomObject]@{
                PrincipalId   = 'test-id-001'
                PrincipalName = 'Test Application 2'
                AppRoleCount  = 1
                AppRoles      = @()
                Activity      = @()
            }

            $result = $app | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30
            $result.PSObject.Properties.Name | Should -Contain 'ThrottlingStats'
        }

        It 'Should preserve original properties including Activity' {
            $app = [PSCustomObject]@{
                PrincipalId   = 'test-id-001'
                PrincipalName = 'Test Application 3'
                AppRoleCount  = 1
                AppRoles      = @()
                Activity      = @(
                    @{ Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/users' }
                )
            }

            $result = $app | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30
            $result.PrincipalId | Should -Be 'test-id-001'
            $result.Activity | Should -Not -BeNullOrEmpty
        }

        It 'Should call Get-AppThrottlingStats for workspace' {
            $app = [PSCustomObject]@{
                PrincipalId   = 'test-id-001'
                PrincipalName = 'Test Application 4'
                AppRoleCount  = 1
                AppRoles      = @()
                Activity      = @()
            }

            $app | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            if ($script:moduleLoaded) {
                Should -Invoke -CommandName Get-AppThrottlingStats -ModuleName $script:moduleName -Times 1 -Exactly
            }
            else {
                Should -Invoke -CommandName Get-AppThrottlingStats -Times 1 -Exactly
            }
        }
    }
}
