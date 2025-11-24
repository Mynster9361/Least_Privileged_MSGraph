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
        $publicFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Public" -Filter "Initialize-LogAnalyticsApi.ps1" -ErrorAction SilentlyContinue

        if ($publicFunction) {
            . $publicFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find Initialize-LogAnalyticsApi.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Initialize-LogAnalyticsApi' {
    Context 'Parameter Validation' {
        It 'Should have no mandatory parameters' {
            $command = Get-Command -Name Initialize-LogAnalyticsApi
            $mandatoryParams = $command.Parameters.Values | Where-Object { $_.Attributes.Mandatory -eq $true }
            $mandatoryParams | Should -BeNullOrEmpty
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command -Name Initialize-LogAnalyticsApi
            $command.CmdletBinding | Should -Be $true
        }
    }

    Context 'Functionality' {
        BeforeAll {
            # Mock Register-EntraService
            if ($script:moduleLoaded) {
                Mock -CommandName Register-EntraService -ModuleName $script:moduleName -MockWith {
                    return [PSCustomObject]@{
                        ServiceName       = 'LogAnalytics'
                        AlreadyRegistered = $false
                        Status            = 'NewlyRegistered'
                    }
                }
            }
            else {
                Mock -CommandName Register-EntraService -MockWith {
                    return [PSCustomObject]@{
                        ServiceName       = 'LogAnalytics'
                        AlreadyRegistered = $false
                        Status            = 'NewlyRegistered'
                    }
                }
            }
        }

        It 'Should register Log Analytics service' {
            $result = Initialize-LogAnalyticsApi
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return object with ServiceName property' {
            $result = Initialize-LogAnalyticsApi
            $result.ServiceName | Should -Be 'LogAnalytics'
        }

        It 'Should call Register-EntraService' {
            Initialize-LogAnalyticsApi
            if ($script:moduleLoaded) {
                Should -Invoke -CommandName Register-EntraService -ModuleName $script:moduleName -Times 1 -Exactly
            }
            else {
                Should -Invoke -CommandName Register-EntraService -Times 1 -Exactly
            }
        }
    }
}
