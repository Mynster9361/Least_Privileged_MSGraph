BeforeAll {
    $script:moduleName = 'LeastPrivilegedMSGraph'

    # Remove any existing module
    Get-Module $script:moduleName -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Create stub for Register-EntraService before importing the module
    if (-not (Get-Command -Name Register-EntraService -ErrorAction SilentlyContinue)) {
        function global:Register-EntraService {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [string]$ServiceName,

                [Parameter(Mandatory)]
                [string]$ResourceId,

                [Parameter()]
                [string[]]$Scopes
            )
        }
    }

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

    # Clean up global stub
    Remove-Item -Path Function:\Register-EntraService -ErrorAction SilentlyContinue
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
            Mock -CommandName Register-EntraService -MockWith {
                param($ServiceName, $ResourceId, $Scopes)
                return [PSCustomObject]@{
                    ServiceName       = $ServiceName
                    ResourceId        = $ResourceId
                    Scopes            = $Scopes
                    AlreadyRegistered = $false
                    Status            = 'NewlyRegistered'
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

        It 'Should handle already registered service' {
            Mock -CommandName Register-EntraService -MockWith {
                return [PSCustomObject]@{
                    ServiceName       = 'LogAnalytics'
                    ResourceId        = 'https://api.loganalytics.io'
                    AlreadyRegistered = $true
                    Status            = 'AlreadyRegistered'
                }
            }

            $result = Initialize-LogAnalyticsApi
            $result.AlreadyRegistered | Should -Be $true
        }
    }

    Context 'Integration' {
        BeforeAll {
            Mock -CommandName Register-EntraService -MockWith {
                param($ServiceName, $ResourceId, $Scopes)
                return [PSCustomObject]@{
                    ServiceName       = $ServiceName
                    ResourceId        = $ResourceId
                    Scopes            = $Scopes
                    AlreadyRegistered = $false
                    Status            = 'NewlyRegistered'
                }
            }
        }

        It 'Should be callable without parameters' {
            { Initialize-LogAnalyticsApi } | Should -Not -Throw
        }

        It 'Should return consistent results on multiple calls' {
            Mock -CommandName Register-EntraService -MockWith {
                return [PSCustomObject]@{
                    ServiceName       = 'LogAnalytics'
                    ResourceId        = 'https://api.loganalytics.io'
                    AlreadyRegistered = $true
                    Status            = 'AlreadyRegistered'
                }
            }

            $result1 = Initialize-LogAnalyticsApi
            $result2 = Initialize-LogAnalyticsApi

            $result1.ServiceName | Should -Be $result2.ServiceName
            $result1.ResourceId | Should -Be $result2.ResourceId
        }
    }
}
