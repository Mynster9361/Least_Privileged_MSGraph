BeforeAll {
    $script:moduleName = 'LeastPrivilegedMSGraph'

    # Remove any existing module instances
    Get-Module $script:moduleName -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Import from the build output directory
    $moduleManifestPath = "$PSScriptRoot\..\..\..\output\module\$script:moduleName\*\$script:moduleName.psd1"
    $manifestPath = Get-Item $moduleManifestPath -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($manifestPath) {
        # Import the built module
        Import-Module $manifestPath.FullName -Force -ErrorAction Stop

        # Dot-source the private function to make it available in tests
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot\..\..\..\source\Private" -Filter "Find-LeastPrivilegedPermission.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
    }
    else {
        # Fallback for manual testing (dot source directly)
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot\..\..\..\source\Private" -Filter "Find-LeastPrivilegedPermission.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
        else {
            throw "Could not find Find-LeastPrivilegedPermission.ps1 and module is not built"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Find-LeastPrivilegedPermission' {
    Context 'Parameter Validation' {
        It 'Should not have mandatory userActivity parameter' {
            $command = Get-Command -Name Find-LeastPrivilegedPermission
            $command.Parameters['userActivity'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should not have mandatory permissionMapv1 parameter' {
            $command = Get-Command -Name Find-LeastPrivilegedPermission
            $command.Parameters['permissionMapv1'].Attributes.Mandatory | Should -Be $false
        }
    }

    Context 'Functionality' {
        BeforeAll {
            # Simplified mock for testing - verify structure first
            $script:mockPermissionMap = @(
                [PSCustomObject]@{
                    Endpoint = '/users'
                    Version  = 'v1.0'
                    Method   = [PSCustomObject]@{
                        GET  = @(
                            [PSCustomObject]@{
                                value              = 'User.Read.All'
                                scopeType          = 'Application'
                                consentDisplayName = $null
                                consentDescription = $null
                                isAdmin            = $true
                                isLeastPrivilege   = $false
                                isHidden           = $false
                            },
                            [PSCustomObject]@{
                                value              = 'User.ReadBasic.All'
                                scopeType          = 'Application'
                                consentDisplayName = $null
                                consentDescription = $null
                                isAdmin            = $true
                                isLeastPrivilege   = $true
                                isHidden           = $false
                            }
                        )
                        POST = @(
                            [PSCustomObject]@{
                                value              = 'User.ReadWrite.All'
                                scopeType          = 'Application'
                                consentDisplayName = $null
                                consentDescription = $null
                                isAdmin            = $true
                                isLeastPrivilege   = $true
                                isHidden           = $false
                            }
                        )
                    }
                }
            )

            $script:mockUserActivity = @(
                [PSCustomObject]@{
                    Method = 'GET'
                    Uri    = 'https://graph.microsoft.com/v1.0/users'
                }
            )
        }

        It 'Should verify mock structure is accessible' {
            # Verify we can access the permissions
            $mockPermissionMap[0].Method.GET | Should -Not -BeNullOrEmpty
            $mockPermissionMap[0].Method.GET.Count | Should -Be 2

            # Verify we can filter by scopeType
            $appPerms = $mockPermissionMap[0].Method.GET | Where-Object { $_.scopeType -eq 'Application' }
            $appPerms.Count | Should -Be 2

            # Verify we can find least privileged
            $leastPriv = $appPerms | Where-Object { $_.isLeastPrivilege -eq $true }
            $leastPriv.value | Should -Be 'User.ReadBasic.All'
        }

        It 'Should find permissions for endpoint' {
            $result = Find-LeastPrivilegedPermission -userActivity $mockUserActivity -permissionMapv1 $mockPermissionMap -permissionMapbeta @()
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return objects with LeastPrivilegedPermissions property' {
            $result = Find-LeastPrivilegedPermission -userActivity $mockUserActivity -permissionMapv1 $mockPermissionMap -permissionMapbeta @()
            $result[0].PSObject.Properties.Name | Should -Contain 'LeastPrivilegedPermissions'
        }


        It 'Should match endpoint correctly' {
            $result = Find-LeastPrivilegedPermission -userActivity $mockUserActivity -permissionMapv1 $mockPermissionMap -permissionMapbeta @()
            $result[0].IsMatched | Should -Be $true
            $result[0].MatchedEndpoint | Should -Be '/users'
        }

        It 'Should handle POST method' {
            $postActivity = @(
                [PSCustomObject]@{
                    Method = 'POST'
                    Uri    = 'https://graph.microsoft.com/v1.0/users'
                }
            )

            $result = Find-LeastPrivilegedPermission -userActivity $postActivity -permissionMapv1 $mockPermissionMap -permissionMapbeta @()
            $result | Should -Not -BeNullOrEmpty
            $result[0].Method | Should -Be 'POST'
            $result[0].LeastPrivilegedPermissions | Should -Not -BeNullOrEmpty

            # Should return User.ReadWrite.All for POST
            $hasWritePerm = $result[0].LeastPrivilegedPermissions | Where-Object { $_.Permission -eq 'User.ReadWrite.All' }
            $hasWritePerm | Should -Not -BeNullOrEmpty
        }
    }
}
