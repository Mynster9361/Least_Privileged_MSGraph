BeforeAll {
    $script:moduleName = 'LeastPrivilegedMSGraph'

    Get-Module $script:moduleName -All | Remove-Module -Force -ErrorAction SilentlyContinue

    $moduleManifestPath = "$PSScriptRoot\..\..\..\output\module\$script:moduleName\*\$script:moduleName.psd1"
    $manifestPath = Get-Item $moduleManifestPath -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($manifestPath) {
        Import-Module $manifestPath.FullName -Force -ErrorAction Stop
    }

    # Private functions are not exported — always dot-source directly
    $privateFunction = Get-ChildItem -Path "$PSScriptRoot\..\..\..\source\Private" -Filter "Get-PermissionRiskLevel.ps1" -ErrorAction SilentlyContinue

    if ($privateFunction) {
        . $privateFunction.FullName
    }
    else {
        throw "Could not find Get-PermissionRiskLevel.ps1"
    }
}

Describe 'Get-PermissionRiskLevel' {

    Context 'Critical override patterns - Application scope' {
        It 'RoleManagement.ReadWrite.All (Application) → Critical' {
            $result = Get-PermissionRiskLevel -PermissionName 'RoleManagement.ReadWrite.All' -ScopeType 'Application'
            $result.Level | Should -Be 4
            $result.Label | Should -Be 'Critical'
        }

        It 'Directory.ReadWrite.All (Application) → Critical' {
            $result = Get-PermissionRiskLevel -PermissionName 'Directory.ReadWrite.All' -ScopeType 'Application'
            $result.Level | Should -Be 4
            $result.Label | Should -Be 'Critical'
        }

        It 'AppRoleAssignment.ReadWrite.All (Application) → Critical' {
            $result = Get-PermissionRiskLevel -PermissionName 'AppRoleAssignment.ReadWrite.All' -ScopeType 'Application'
            $result.Level | Should -Be 4
            $result.Label | Should -Be 'Critical'
        }

        It 'Application.ReadWrite.All (Application) → Critical' {
            $result = Get-PermissionRiskLevel -PermissionName 'Application.ReadWrite.All' -ScopeType 'Application'
            $result.Level | Should -Be 4
            $result.Label | Should -Be 'Critical'
        }

        It 'Policy.ReadWrite.ConditionalAccess (Application) → Critical' {
            $result = Get-PermissionRiskLevel -PermissionName 'Policy.ReadWrite.ConditionalAccess' -ScopeType 'Application'
            $result.Level | Should -Be 4
            $result.Label | Should -Be 'Critical'
        }

        It 'UserAuthenticationMethod.ReadWrite.All (Application) → Critical' {
            $result = Get-PermissionRiskLevel -PermissionName 'UserAuthenticationMethod.ReadWrite.All' -ScopeType 'Application'
            $result.Level | Should -Be 4
            $result.Label | Should -Be 'Critical'
        }
    }

    Context 'Critical override patterns - Delegated scope (becomes High due to user ceiling)' {
        It 'RoleManagement.ReadWrite.All (Delegated) → High' {
            $result = Get-PermissionRiskLevel -PermissionName 'RoleManagement.ReadWrite.All' -ScopeType 'Delegated'
            $result.Level | Should -Be 3
            $result.Label | Should -Be 'High'
        }

        It 'Directory.ReadWrite.All (DelegatedWork) → High' {
            $result = Get-PermissionRiskLevel -PermissionName 'Directory.ReadWrite.All' -ScopeType 'DelegatedWork'
            $result.Level | Should -Be 3
            $result.Label | Should -Be 'High'
        }
    }

    Context 'High override patterns - Application scope' {
        It 'Directory.Read.All (Application) → High' {
            $result = Get-PermissionRiskLevel -PermissionName 'Directory.Read.All' -ScopeType 'Application'
            $result.Level | Should -Be 3
            $result.Label | Should -Be 'High'
        }

        It 'Mail.Send (Application) → High' {
            $result = Get-PermissionRiskLevel -PermissionName 'Mail.Send' -ScopeType 'Application'
            $result.Level | Should -Be 3
            $result.Label | Should -Be 'High'
        }

        It 'AuditLog.Read.All (Application) → High' {
            $result = Get-PermissionRiskLevel -PermissionName 'AuditLog.Read.All' -ScopeType 'Application'
            $result.Level | Should -Be 3
            $result.Label | Should -Be 'High'
        }

        It 'Files.ReadWrite.All (Application) → High' {
            $result = Get-PermissionRiskLevel -PermissionName 'Files.ReadWrite.All' -ScopeType 'Application'
            $result.Level | Should -Be 3
            $result.Label | Should -Be 'High'
        }

        It 'BitlockerKey.Read.All (Application) → High' {
            $result = Get-PermissionRiskLevel -PermissionName 'BitlockerKey.Read.All' -ScopeType 'Application'
            $result.Level | Should -Be 3
            $result.Label | Should -Be 'High'
        }
    }

    Context 'High override patterns - Delegated scope (becomes Medium)' {
        It 'Directory.Read.All (Delegated) → Medium' {
            $result = Get-PermissionRiskLevel -PermissionName 'Directory.Read.All' -ScopeType 'Delegated'
            $result.Level | Should -Be 2
            $result.Label | Should -Be 'Medium'
        }

        It 'Mail.Send (DelegatedWork) → Medium' {
            $result = Get-PermissionRiskLevel -PermissionName 'Mail.Send' -ScopeType 'DelegatedWork'
            $result.Level | Should -Be 2
            $result.Label | Should -Be 'Medium'
        }

        It 'AuditLog.Read.All (Delegated) → Medium' {
            $result = Get-PermissionRiskLevel -PermissionName 'AuditLog.Read.All' -ScopeType 'Delegated'
            $result.Level | Should -Be 2
            $result.Label | Should -Be 'Medium'
        }
    }

    Context 'Name-pattern analysis with scope bump (no schema)' {
        It 'SomeService.ReadWrite.All (Application) → level 3 name + 1 scope bump = Critical' {
            $result = Get-PermissionRiskLevel -PermissionName 'SomeService.ReadWrite.All' -ScopeType 'Application'
            $result.Level | Should -Be 4
            $result.Label | Should -Be 'Critical'
        }

        It 'SomeService.ReadWrite.All (Delegated) → level 3 from name, no bump = High' {
            $result = Get-PermissionRiskLevel -PermissionName 'SomeService.ReadWrite.All' -ScopeType 'Delegated'
            $result.Level | Should -Be 3
            $result.Label | Should -Be 'High'
        }

        It 'SomeService.Read.All (Application) → level 2 name + 1 scope bump = High' {
            $result = Get-PermissionRiskLevel -PermissionName 'SomeService.Read.All' -ScopeType 'Application'
            $result.Level | Should -Be 3
            $result.Label | Should -Be 'High'
        }

        It 'SomeService.Read.All (Delegated) → level 2 from name, no bump = Medium' {
            $result = Get-PermissionRiskLevel -PermissionName 'SomeService.Read.All' -ScopeType 'Delegated'
            $result.Level | Should -Be 2
            $result.Label | Should -Be 'Medium'
        }

        It 'SomeService.ReadWrite (Delegated) → level 2 from name = Medium' {
            $result = Get-PermissionRiskLevel -PermissionName 'SomeService.ReadWrite' -ScopeType 'Delegated'
            $result.Level | Should -Be 2
            $result.Label | Should -Be 'Medium'
        }

        It 'SomeService.ReadWrite (Application) → level 2 + 1 bump = High' {
            $result = Get-PermissionRiskLevel -PermissionName 'SomeService.ReadWrite' -ScopeType 'Application'
            $result.Level | Should -Be 3
            $result.Label | Should -Be 'High'
        }
    }

    Context 'Low-risk well-known permissions' {
        It 'User.Read (Delegated) → Low' {
            $result = Get-PermissionRiskLevel -PermissionName 'User.Read' -ScopeType 'Delegated'
            $result.Level | Should -Be 1
            $result.Label | Should -Be 'Low'
        }

        It 'openid (Delegated) → Low' {
            $result = Get-PermissionRiskLevel -PermissionName 'openid' -ScopeType 'Delegated'
            $result.Level | Should -Be 1
            $result.Label | Should -Be 'Low'
        }

        It 'profile (Delegated) → Low' {
            $result = Get-PermissionRiskLevel -PermissionName 'profile' -ScopeType 'Delegated'
            $result.Level | Should -Be 1
            $result.Label | Should -Be 'Low'
        }

        It 'email (Delegated) → Low' {
            $result = Get-PermissionRiskLevel -PermissionName 'email' -ScopeType 'Delegated'
            $result.Level | Should -Be 1
            $result.Label | Should -Be 'Low'
        }
    }

    Context 'Schema integration' {
        It 'Uses schema level as baseline when no override matches' {
            # Simulate a schema that gives level 3 for a non-overridden permission
            $mockSchema = @{
                permissions = @{
                    'CustomService.Read' = @{
                        schemes = @{
                            DelegatedWork = @{ privilegeLevel = 3 }
                            Application   = @{ privilegeLevel = 3 }
                        }
                    }
                }
            }

            $result = Get-PermissionRiskLevel -PermissionName 'CustomService.Read' -ScopeType 'Delegated' -Schema $mockSchema
            $result.Level | Should -Be 3
            $result.Label | Should -Be 'High'
        }

        It 'Schema level is bumped by +1 for Application scope' {
            $mockSchema = @{
                permissions = @{
                    'CustomService.Read' = @{
                        schemes = @{
                            Application = @{ privilegeLevel = 2 }
                        }
                    }
                }
            }

            $result = Get-PermissionRiskLevel -PermissionName 'CustomService.Read' -ScopeType 'Application' -Schema $mockSchema
            $result.Level | Should -Be 3
            $result.Label | Should -Be 'High'
        }

        It 'Application scope bump is capped at 4' {
            $mockSchema = @{
                permissions = @{
                    'CustomService.ReadWrite.All' = @{
                        schemes = @{
                            Application = @{ privilegeLevel = 4 }
                        }
                    }
                }
            }

            $result = Get-PermissionRiskLevel -PermissionName 'CustomService.ReadWrite.All' -ScopeType 'Application' -Schema $mockSchema
            $result.Level | Should -Be 4
            $result.Label | Should -Be 'Critical'
        }

        It 'Works correctly without a schema (graceful fallback)' {
            $result = Get-PermissionRiskLevel -PermissionName 'User.Read' -ScopeType 'Delegated' -Schema $null
            $result.Level | Should -Be 1
            $result.Label | Should -Be 'Low'
        }
    }

    Context 'Output object structure' {
        It 'Returns a PSCustomObject with Level and Label properties' {
            $result = Get-PermissionRiskLevel -PermissionName 'User.Read.All' -ScopeType 'Application'
            $result | Should -BeOfType [PSCustomObject]
            $result.PSObject.Properties.Name | Should -Contain 'Level'
            $result.PSObject.Properties.Name | Should -Contain 'Label'
        }

        It 'Level is always an integer between 1 and 4' {
            $permissions = @('User.Read', 'User.Read.All', 'User.ReadWrite.All', 'Directory.ReadWrite.All', 'RoleManagement.ReadWrite.All')
            foreach ($perm in $permissions) {
                $result = Get-PermissionRiskLevel -PermissionName $perm -ScopeType 'Application'
                $result.Level | Should -BeIn @(1, 2, 3, 4)
            }
        }

        It 'Label matches Level consistently' {
            $labelMap = @{ 1 = 'Low'; 2 = 'Medium'; 3 = 'High'; 4 = 'Critical' }
            $permissions = @('profile', 'Group.Read.All', 'AuditLog.Read.All', 'RoleManagement.ReadWrite.All')
            foreach ($perm in $permissions) {
                $result = Get-PermissionRiskLevel -PermissionName $perm -ScopeType 'Application'
                $result.Label | Should -Be $labelMap[$result.Level]
            }
        }
    }
}
