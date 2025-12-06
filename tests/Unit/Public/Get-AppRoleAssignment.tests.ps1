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
        $publicFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Public" -Filter "Get-AppRoleAssignment.ps1" -ErrorAction SilentlyContinue

        if ($publicFunction) {
            . $publicFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find Get-AppRoleAssignment.ps1"
        }
    }

    # Mock data based on anonymized production output
    $script:mockServicePrincipals = @(
        @{
            id                  = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            appId               = '11111111-1111-1111-1111-111111111111'
            displayName         = 'TestApp-DirectoryReader'
            servicePrincipalType = 'Application'
        }
        @{
            id                  = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            appId               = '22222222-2222-2222-2222-222222222222'
            displayName         = 'TestApp-SharePointReader'
            servicePrincipalType = 'Application'
        }
        @{
            id                  = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
            appId               = '33333333-3333-3333-3333-333333333333'
            displayName         = 'TestApp-UserManager'
            servicePrincipalType = 'Application'
        }
        @{
            id                  = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
            appId               = '44444444-4444-4444-4444-444444444444'
            displayName         = 'TestApp-MailProcessor'
            servicePrincipalType = 'Application'
        }
        @{
            id                  = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
            appId               = '55555555-5555-5555-5555-555555555555'
            displayName         = 'TestApp-MultiPermission'
            servicePrincipalType = 'Application'
        }
        @{
            id                  = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
            appId               = '66666666-6666-6666-6666-666666666666'
            displayName         = 'TestApp-LicenseManager'
            servicePrincipalType = 'Application'
        }
        @{
            id                  = '00000000-0000-0000-0000-000000000000'
            appId               = '77777777-7777-7777-7777-777777777777'
            displayName         = 'TestApp-NoPermissions'
            servicePrincipalType = 'Application'
        }
    )

    $script:mockAppRoleAssignments = @{
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' = @(
            @{
                id            = 'assignment-1'
                appRoleId     = '7ab1d382-f21e-4acd-a863-ba3e13f7da61'
                principalId   = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                resourceId    = 'graph-resource-id'
                principalType = 'ServicePrincipal'
            }
            @{
                id            = 'assignment-2'
                appRoleId     = 'df021288-bdef-4463-88db-98f22de89214'
                principalId   = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                resourceId    = 'graph-resource-id'
                principalType = 'ServicePrincipal'
            }
        )
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' = @(
            @{
                id            = 'assignment-3'
                appRoleId     = '883ea226-0bf2-4a8f-9f9d-92c9162a727d'
                principalId   = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
                resourceId    = 'graph-resource-id'
                principalType = 'ServicePrincipal'
            }
        )
        'cccccccc-cccc-cccc-cccc-cccccccccccc' = @(
            @{
                id            = 'assignment-4'
                appRoleId     = '741f803b-c850-494e-b5df-cde7c675a1ca'
                principalId   = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
                resourceId    = 'graph-resource-id'
                principalType = 'ServicePrincipal'
            }
        )
        'dddddddd-dddd-dddd-dddd-dddddddddddd' = @(
            @{
                id            = 'assignment-5'
                appRoleId     = '97235f07-e226-4f63-ace3-39588e11d3a1'
                principalId   = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
                resourceId    = 'graph-resource-id'
                principalType = 'ServicePrincipal'
            }
            @{
                id            = 'assignment-6'
                appRoleId     = 'e2a3a72e-5f79-4c64-b1b1-878b674786c9'
                principalId   = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
                resourceId    = 'graph-resource-id'
                principalType = 'ServicePrincipal'
            }
        )
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee' = @(
            @{
                id            = 'assignment-7'
                appRoleId     = 'df021288-bdef-4463-88db-98f22de89214'
                principalId   = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
                resourceId    = 'graph-resource-id'
                principalType = 'ServicePrincipal'
            }
            @{
                id            = 'assignment-8'
                appRoleId     = 'b633e1c5-b582-4048-a93e-9f11b44c7e96'
                principalId   = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
                resourceId    = 'graph-resource-id'
                principalType = 'ServicePrincipal'
            }
            @{
                id            = 'assignment-9'
                appRoleId     = '294ce7c9-31ba-490a-ad7d-97a7d075e4ed'
                principalId   = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
                resourceId    = 'graph-resource-id'
                principalType = 'ServicePrincipal'
            }
            @{
                id            = 'assignment-10'
                appRoleId     = 'd9c48af6-9ad9-47ad-82c3-63757137b9af'
                principalId   = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
                resourceId    = 'graph-resource-id'
                principalType = 'ServicePrincipal'
            }
        )
        'ffffffff-ffff-ffff-ffff-ffffffffffff' = @(
            @{
                id            = 'assignment-11'
                appRoleId     = '883ea226-0bf2-4a8f-9f9d-92c9162a727d'
                principalId   = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
                resourceId    = 'graph-resource-id'
                principalType = 'ServicePrincipal'
            }
            @{
                id            = 'assignment-12'
                appRoleId     = 'df021288-bdef-4463-88db-98f22de89214'
                principalId   = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
                resourceId    = 'graph-resource-id'
                principalType = 'ServicePrincipal'
            }
            @{
                id            = 'assignment-13'
                appRoleId     = '5facf0c1-8979-4e95-abcf-ff3d079771c0'
                principalId   = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
                resourceId    = 'graph-resource-id'
                principalType = 'ServicePrincipal'
            }
        )
        '00000000-0000-0000-0000-000000000000' = @()
    )

    $script:mockGraphResource = @{
        id          = 'graph-resource-id'
        displayName = 'Microsoft Graph'
        appRoles    = @(
            @{
                id          = '7ab1d382-f21e-4acd-a863-ba3e13f7da61'
                value       = 'Directory.Read.All'
                displayName = 'Read directory data'
            }
            @{
                id          = 'df021288-bdef-4463-88db-98f22de89214'
                value       = 'User.Read.All'
                displayName = 'Read all users'' full profiles'
            }
            @{
                id          = '883ea226-0bf2-4a8f-9f9d-92c9162a727d'
                value       = 'Sites.Selected'
                displayName = 'Access selected site collections'
            }
            @{
                id          = '741f803b-c850-494e-b5df-cde7c675a1ca'
                value       = 'User.ReadWrite.All'
                displayName = 'Read and write all users'' full profiles'
            }
            @{
                id          = '97235f07-e226-4f63-ace3-39588e11d3a1'
                value       = 'User.ReadBasic.All'
                displayName = 'Read all users'' basic profiles'
            }
            @{
                id          = 'e2a3a72e-5f79-4c64-b1b1-878b674786c9'
                value       = 'Mail.ReadWrite'
                displayName = 'Read and write mail in all mailboxes'
            }
            @{
                id          = 'b633e1c5-b582-4048-a93e-9f11b44c7e96'
                value       = 'Mail.Send'
                displayName = 'Send mail as any user'
            }
            @{
                id          = '294ce7c9-31ba-490a-ad7d-97a7d075e4ed'
                value       = 'Chat.ReadWrite.All'
                displayName = 'Read and write all chat messages'
            }
            @{
                id          = 'd9c48af6-9ad9-47ad-82c3-63757137b9af'
                value       = 'Chat.Create'
                displayName = 'Create chats'
            }
            @{
                id          = '5facf0c1-8979-4e95-abcf-ff3d079771c0'
                value       = 'LicenseAssignment.ReadWrite.All'
                displayName = 'Read and write all license assignments'
            }
        )
    }
}

Describe 'Get-AppRoleAssignment' {
    Context 'Parameter Validation' {
        It 'Should have no mandatory parameters' {
            $command = Get-Command -Name Get-AppRoleAssignment
            $mandatoryParams = $command.Parameters.Values | Where-Object { $_.Attributes.Mandatory -eq $true }
            $mandatoryParams | Should -BeNullOrEmpty
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command -Name Get-AppRoleAssignment
            $command.CmdletBinding | Should -Be $true
        }
    }

    Context 'Basic Functionality' {
        BeforeEach {
            # Mock Invoke-EntraRequest to return our test data
            Mock -CommandName Invoke-EntraRequest -MockWith {
                param($Uri, $Method)

                if ($Uri -like '*/servicePrincipals?*') {
                    return @{
                        value = $script:mockServicePrincipals
                    }
                }
                elseif ($Uri -match '/servicePrincipals/([^/]+)/appRoleAssignments') {
                    $spId = $Matches[1]
                    return @{
                        value = $script:mockAppRoleAssignments[$spId]
                    }
                }
                elseif ($Uri -like '*/servicePrincipals/*' -and $Uri -notlike '*appRoleAssignments*') {
                    return $script:mockGraphResource
                }

                return @{ value = @() }
            } -ModuleName $script:moduleName
        }

        It 'Should return app role assignments' {
            $result = Get-AppRoleAssignment

            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Should return objects with required properties' {
            $result = Get-AppRoleAssignment

            $result[0].PSObject.Properties.Name | Should -Contain 'PrincipalId'
            $result[0].PSObject.Properties.Name | Should -Contain 'PrincipalName'
            $result[0].PSObject.Properties.Name | Should -Contain 'AppRoleCount'
            $result[0].PSObject.Properties.Name | Should -Contain 'AppRoles'
        }

        It 'Should return multiple service principals' {
            $result = Get-AppRoleAssignment

            $result.Count | Should -BeGreaterThan 1
        }

        It 'Should include service principal names' {
            $result = Get-AppRoleAssignment

            $result.PrincipalName | Should -Contain 'TestApp-DirectoryReader'
            $result.PrincipalName | Should -Contain 'TestApp-SharePointReader'
            $result.PrincipalName | Should -Contain 'TestApp-MultiPermission'
        }

        It 'Should include service principal IDs' {
            $result = Get-AppRoleAssignment

            $result.PrincipalId | Should -Contain 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            $result.PrincipalId | Should -Contain 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
        }
    }

    Context 'App Role Details' {
        BeforeEach {
            Mock -CommandName Invoke-EntraRequest -MockWith {
                param($Uri, $Method)

                if ($Uri -like '*/servicePrincipals?*') {
                    return @{
                        value = $script:mockServicePrincipals
                    }
                }
                elseif ($Uri -match '/servicePrincipals/([^/]+)/appRoleAssignments') {
                    $spId = $Matches[1]
                    return @{
                        value = $script:mockAppRoleAssignments[$spId]
                    }
                }
                elseif ($Uri -like '*/servicePrincipals/*' -and $Uri -notlike '*appRoleAssignments*') {
                    return $script:mockGraphResource
                }

                return @{ value = @() }
            } -ModuleName $script:moduleName
        }

        It 'Should return correct app role count' {
            $result = Get-AppRoleAssignment

            $directoryReader = $result | Where-Object { $_.PrincipalName -eq 'TestApp-DirectoryReader' }
            $directoryReader.AppRoleCount | Should -Be 2

            $multiPerm = $result | Where-Object { $_.PrincipalName -eq 'TestApp-MultiPermission' }
            $multiPerm.AppRoleCount | Should -Be 4
        }

        It 'Should include app role details with appRoleId' {
            $result = Get-AppRoleAssignment

            $firstApp = $result[0]
            $firstApp.AppRoles | Should -Not -BeNullOrEmpty
            $firstApp.AppRoles[0].appRoleId | Should -Not -BeNullOrEmpty
        }

        It 'Should include friendly permission names' {
            $result = Get-AppRoleAssignment

            $directoryReader = $result | Where-Object { $_.PrincipalName -eq 'TestApp-DirectoryReader' }
            $directoryReader.AppRoles.FriendlyName | Should -Contain 'Directory.Read.All'
            $directoryReader.AppRoles.FriendlyName | Should -Contain 'User.Read.All'
        }

        It 'Should include permission type' {
            $result = Get-AppRoleAssignment

            $firstApp = $result[0]
            $firstApp.AppRoles[0].PermissionType | Should -Be 'Application'
        }

        It 'Should include resource display name' {
            $result = Get-AppRoleAssignment

            $firstApp = $result[0]
            $firstApp.AppRoles[0].resourceDisplayName | Should -Be 'Microsoft Graph'
        }

        It 'Should handle apps with single permission' {
            $result = Get-AppRoleAssignment

            $sharePointReader = $result | Where-Object { $_.PrincipalName -eq 'TestApp-SharePointReader' }
            $sharePointReader.AppRoleCount | Should -Be 1
            $sharePointReader.AppRoles.FriendlyName | Should -Be 'Sites.Selected'
        }

        It 'Should handle apps with multiple permissions' {
            $result = Get-AppRoleAssignment

            $multiPerm = $result | Where-Object { $_.PrincipalName -eq 'TestApp-MultiPermission' }
            $multiPerm.AppRoleCount | Should -Be 4
            $multiPerm.AppRoles.Count | Should -Be 4
        }

        It 'Should handle apps with no permissions' {
            $result = Get-AppRoleAssignment

            $noPerms = $result | Where-Object { $_.PrincipalName -eq 'TestApp-NoPermissions' }
            $noPerms.AppRoleCount | Should -Be 0
            $noPerms.AppRoles | Should -BeNullOrEmpty -Or ($noPerms.AppRoles.Count -eq 0)
        }
    }

    Context 'Permission Variety' {
        BeforeEach {
            Mock -CommandName Invoke-EntraRequest -MockWith {
                param($Uri, $Method)

                if ($Uri -like '*/servicePrincipals?*') {
                    return @{
                        value = $script:mockServicePrincipals
                    }
                }
                elseif ($Uri -match '/servicePrincipals/([^/]+)/appRoleAssignments') {
                    $spId = $Matches[1]
                    return @{
                        value = $script:mockAppRoleAssignments[$spId]
                    }
                }
                elseif ($Uri -like '*/servicePrincipals/*' -and $Uri -notlike '*appRoleAssignments*') {
                    return $script:mockGraphResource
                }

                return @{ value = @() }
            } -ModuleName $script:moduleName
        }

        It 'Should include Directory permissions' {
            $result = Get-AppRoleAssignment

            $allPermissions = $result.AppRoles.FriendlyName
            $allPermissions | Should -Contain 'Directory.Read.All'
        }

        It 'Should include User permissions' {
            $result = Get-AppRoleAssignment

            $allPermissions = $result.AppRoles.FriendlyName
            $allPermissions | Should -Contain 'User.Read.All'
            $allPermissions | Should -Contain 'User.ReadWrite.All'
            $allPermissions | Should -Contain 'User.ReadBasic.All'
        }

        It 'Should include Sites permissions' {
            $result = Get-AppRoleAssignment

            $allPermissions = $result.AppRoles.FriendlyName
            $allPermissions | Should -Contain 'Sites.Selected'
        }

        It 'Should include Mail permissions' {
            $result = Get-AppRoleAssignment

            $allPermissions = $result.AppRoles.FriendlyName
            $allPermissions | Should -Contain 'Mail.ReadWrite'
            $allPermissions | Should -Contain 'Mail.Send'
        }

        It 'Should include Chat permissions' {
            $result = Get-AppRoleAssignment

            $allPermissions = $result.AppRoles.FriendlyName
            $allPermissions | Should -Contain 'Chat.ReadWrite.All'
            $allPermissions | Should -Contain 'Chat.Create'
        }

        It 'Should include License permissions' {
            $result = Get-AppRoleAssignment

            $allPermissions = $result.AppRoles.FriendlyName
            $allPermissions | Should -Contain 'LicenseAssignment.ReadWrite.All'
        }
    }

    Context 'Error Handling' {
        It 'Should handle API errors gracefully' {
            Mock -CommandName Invoke-EntraRequest -MockWith {
                throw "API Error: Service Unavailable"
            } -ModuleName $script:moduleName

            { Get-AppRoleAssignment } | Should -Throw
        }

        It 'Should handle empty response' {
            Mock -CommandName Invoke-EntraRequest -MockWith {
                return @{ value = @() }
            } -ModuleName $script:moduleName

            $result = Get-AppRoleAssignment
            $result | Should -BeNullOrEmpty -Or ($result.Count -eq 0)
        }

        It 'Should handle missing app role assignments' {
            Mock -CommandName Invoke-EntraRequest -MockWith {
                param($Uri, $Method)

                if ($Uri -like '*/servicePrincipals?*') {
                    return @{
                        value = @($script:mockServicePrincipals[0])
                    }
                }
                elseif ($Uri -match '/servicePrincipals/([^/]+)/appRoleAssignments') {
                    return @{ value = @() }
                }
                elseif ($Uri -like '*/servicePrincipals/*') {
                    return $script:mockGraphResource
                }

                return @{ value = @() }
            } -ModuleName $script:moduleName

            $result = Get-AppRoleAssignment
            $result | Should -Not -BeNullOrEmpty
            $result.AppRoleCount | Should -Be 0
        }
    }

    Context 'Data Consistency' {
        BeforeEach {
            Mock -CommandName Invoke-EntraRequest -MockWith {
                param($Uri, $Method)

                if ($Uri -like '*/servicePrincipals?*') {
                    return @{
                        value = $script:mockServicePrincipals
                    }
                }
                elseif ($Uri -match '/servicePrincipals/([^/]+)/appRoleAssignments') {
                    $spId = $Matches[1]
                    return @{
                        value = $script:mockAppRoleAssignments[$spId]
                    }
                }
                elseif ($Uri -like '*/servicePrincipals/*' -and $Uri -notlike '*appRoleAssignments*') {
                    return $script:mockGraphResource
                }

                return @{ value = @() }
            } -ModuleName $script:moduleName
        }

        It 'Should have matching PrincipalId in results and app roles' {
            $result = Get-AppRoleAssignment

            foreach ($app in $result) {
                if ($app.AppRoles) {
                    # All app roles should be associated with this principal
                    $app.PrincipalId | Should -Not -BeNullOrEmpty
                }
            }
        }

        It 'Should have AppRoleCount matching actual AppRoles array length' {
            $result = Get-AppRoleAssignment

            foreach ($app in $result) {
                if ($app.AppRoles) {
                    $app.AppRoleCount | Should -Be $app.AppRoles.Count
                }
                else {
                    $app.AppRoleCount | Should -Be 0
                }
            }
        }

        It 'Should not have duplicate app role IDs within same principal' {
            $result = Get-AppRoleAssignment

            foreach ($app in $result | Where-Object { $_.AppRoleCount -gt 1 }) {
                $uniqueRoleIds = $app.AppRoles.appRoleId | Select-Object -Unique
                $uniqueRoleIds.Count | Should -Be $app.AppRoles.Count
            }
        }
    }

    Context 'Output Format' {
        BeforeEach {
            Mock -CommandName Invoke-EntraRequest -MockWith {
                param($Uri, $Method)

                if ($Uri -like '*/servicePrincipals?*') {
                    return @{
                        value = $script:mockServicePrincipals
                    }
                }
                elseif ($Uri -match '/servicePrincipals/([^/]+)/appRoleAssignments') {
                    $spId = $Matches[1]
                    return @{
                        value = $script:mockAppRoleAssignments[$spId]
                    }
                }
                elseif ($Uri -like '*/servicePrincipals/*' -and $Uri -notlike '*appRoleAssignments*') {
                    return $script:mockGraphResource
                }

                return @{ value = @() }
            } -ModuleName $script:moduleName
        }

        It 'Should return PSCustomObject type' {
            $result = Get-AppRoleAssignment

            $result[0] | Should -BeOfType [PSCustomObject]
        }

        It 'Should have PrincipalId as string/guid' {
            $result = Get-AppRoleAssignment

            $result[0].PrincipalId | Should -Match '^[a-f0-9\-]{36}$'
        }

        It 'Should have PrincipalName as string' {
            $result = Get-AppRoleAssignment

            $result[0].PrincipalName | Should -BeOfType [string]
        }

        It 'Should have AppRoleCount as integer' {
            $result = Get-AppRoleAssignment

            $result[0].AppRoleCount | Should -BeOfType [int]
        }

        It 'Should have AppRoles as array or empty' {
            $result = Get-AppRoleAssignment

            foreach ($app in $result) {
                if ($app.AppRoleCount -gt 0) {
                    $app.AppRoles | Should -BeOfType [array]
                }
            }
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}
