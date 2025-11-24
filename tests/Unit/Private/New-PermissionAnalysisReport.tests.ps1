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
        $publicFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Public" -Filter "New-PermissionAnalysisReport.ps1" -ErrorAction SilentlyContinue

        if ($publicFunction) {
            . $publicFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find New-PermissionAnalysisReport.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'New-PermissionAnalysisReport' {
    Context 'Parameter Validation' {
        It 'Should have mandatory AppData parameter' {
            $command = Get-Command -Name New-PermissionAnalysisReport
            $command.Parameters['AppData'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have mandatory OutputPath parameter' {
            $command = Get-Command -Name New-PermissionAnalysisReport
            $command.Parameters['OutputPath'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should accept pipeline input for AppData' {
            $command = Get-Command -Name New-PermissionAnalysisReport
            $command.Parameters['AppData'].Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command -Name New-PermissionAnalysisReport
            $command.CmdletBinding | Should -Be $true
        }
    }

    Context 'Functionality' {
        BeforeAll {
            $testOutputPath = Join-Path -Path $TestDrive -ChildPath 'test-report.html'
        }

        It 'Should create HTML report file' {
            $app = [PSCustomObject]@{
                PrincipalId         = 'test-id-001'
                PrincipalName       = 'Test Application'
                AppRoleCount        = 1
                AppRoles            = @(
                    @{ FriendlyName = 'User.Read.All' }
                )
                Activity            = @(
                    @{
                        Method = 'GET'
                        Uri    = 'https://graph.microsoft.com/v1.0/users'
                    }
                )
                CurrentPermissions  = @('User.Read.All')
                OptimalPermissions  = @(
                    @{
                        Permission        = 'User.ReadBasic.All'
                        ScopeType         = 'Application'
                        IsLeastPrivilege  = $true
                        ActivitiesCovered = 1
                    }
                )
                ExcessPermissions   = @()
                RequiredPermissions = @('User.ReadBasic.All')
                ThrottlingStats     = @{
                    TotalRequests      = 100
                    SuccessfulRequests = 95
                    ThrottleRate       = 0
                    ErrorRate          = 5
                }
            }

            $app | New-PermissionAnalysisReport -OutputPath $testOutputPath
            Test-Path $testOutputPath | Should -Be $true
        }

        It 'Should create valid HTML content' {
            $app = [PSCustomObject]@{
                PrincipalId         = 'test-id-002'
                PrincipalName       = 'Test Application 2'
                AppRoleCount        = 1
                AppRoles            = @()
                Activity            = @()
                CurrentPermissions  = @('User.Read.All')
                OptimalPermissions  = @()
                ExcessPermissions   = @()
                RequiredPermissions = @()
                ThrottlingStats     = @{}
            }

            $app | New-PermissionAnalysisReport -OutputPath $testOutputPath
            $content = Get-Content $testOutputPath -Raw
            $content | Should -Match '<!DOCTYPE html>'
            $content | Should -Match '<html'
            $content | Should -Match '</html>'
        }

        It 'Should handle multiple applications in pipeline' {
            $apps = @(
                [PSCustomObject]@{
                    PrincipalId         = 'test-id-003'
                    PrincipalName       = 'Test Application 3'
                    AppRoleCount        = 1
                    AppRoles            = @()
                    Activity            = @()
                    CurrentPermissions  = @()
                    OptimalPermissions  = @()
                    ExcessPermissions   = @()
                    RequiredPermissions = @()
                    ThrottlingStats     = @{}
                },
                [PSCustomObject]@{
                    PrincipalId         = 'test-id-004'
                    PrincipalName       = 'Test Application 4'
                    AppRoleCount        = 1
                    AppRoles            = @()
                    Activity            = @()
                    CurrentPermissions  = @()
                    OptimalPermissions  = @()
                    ExcessPermissions   = @()
                    RequiredPermissions = @()
                    ThrottlingStats     = @{}
                }
            )

            $apps | New-PermissionAnalysisReport -OutputPath $testOutputPath
            Test-Path $testOutputPath | Should -Be $true

            $content = Get-Content $testOutputPath -Raw
            $content | Should -Match 'Test Application 3'
            $content | Should -Match 'Test Application 4'
        }

        It 'Should include application data in JSON format' {
            $app = [PSCustomObject]@{
                PrincipalId         = 'test-id-005'
                PrincipalName       = 'Test Application 5'
                AppRoleCount        = 1
                AppRoles            = @()
                Activity            = @()
                CurrentPermissions  = @()
                OptimalPermissions  = @()
                ExcessPermissions   = @()
                RequiredPermissions = @()
                ThrottlingStats     = @{}
            }

            $app | New-PermissionAnalysisReport -OutputPath $testOutputPath
            $content = Get-Content $testOutputPath -Raw
            $content | Should -Match 'const appData'
        }
    }
}
