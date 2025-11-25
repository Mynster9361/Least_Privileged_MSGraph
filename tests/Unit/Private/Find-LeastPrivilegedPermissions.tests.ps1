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
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "Find-LeastPrivilegedPermissions.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find Find-LeastPrivilegedPermissions.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Find-LeastPrivilegedPermissions' {
    Context 'Parameter Validation' {
        It 'Should have mandatory userActivity parameter' {
            $command = Get-Command -Name Find-LeastPrivilegedPermissions
            $command.Parameters['userActivity'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have mandatory permissionMapv1 parameter' {
            $command = Get-Command -Name Find-LeastPrivilegedPermissions
            $command.Parameters['permissionMapv1'].Attributes.Mandatory | Should -Be $true
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
            $result = Find-LeastPrivilegedPermissions -userActivity $mockUserActivity -permissionMapv1 $mockPermissionMap -permissionMapbeta @()
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return objects with LeastPrivilegedPermissions property' {
            $result = Find-LeastPrivilegedPermissions -userActivity $mockUserActivity -permissionMapv1 $mockPermissionMap -permissionMapbeta @()
            $result[0].PSObject.Properties.Name | Should -Contain 'LeastPrivilegedPermissions'
        }

        It 'Should identify least privileged permissions correctly' {
            $result = Find-LeastPrivilegedPermissions -userActivity $mockUserActivity -permissionMapv1 $mockPermissionMap -permissionMapbeta @()

            # The function should return User.ReadBasic.All as the least privileged permission
            $result[0].LeastPrivilegedPermissions | Should -Not -BeNullOrEmpty
            $result[0].LeastPrivilegedPermissions.Count | Should -BeGreaterThan 0

            # Check if User.ReadBasic.All is in the results
            $hasLeastPriv = $result[0].LeastPrivilegedPermissions | Where-Object { $_.Permission -eq 'User.ReadBasic.All' }
            $hasLeastPriv | Should -Not -BeNullOrEmpty
        }

        It 'Should match endpoint correctly' {
            $result = Find-LeastPrivilegedPermissions -userActivity $mockUserActivity -permissionMapv1 $mockPermissionMap -permissionMapbeta @()
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

            $result = Find-LeastPrivilegedPermissions -userActivity $postActivity -permissionMapv1 $mockPermissionMap -permissionMapbeta @()
            $result | Should -Not -BeNullOrEmpty
            $result[0].Method | Should -Be 'POST'
            $result[0].LeastPrivilegedPermissions | Should -Not -BeNullOrEmpty

            # Should return User.ReadWrite.All for POST
            $hasWritePerm = $result[0].LeastPrivilegedPermissions | Where-Object { $_.Permission -eq 'User.ReadWrite.All' }
            $hasWritePerm | Should -Not -BeNullOrEmpty
        }
    }
}
