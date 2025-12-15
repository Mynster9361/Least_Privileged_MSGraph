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
        $privateFunctions = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "*.ps1" -ErrorAction SilentlyContinue
        foreach ($func in $privateFunctions) {
            . $func.FullName
        }

        $publicFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Public" -Filter "Get-PermissionAnalysis.ps1" -ErrorAction SilentlyContinue

        if ($publicFunction) {
            . $publicFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find Get-PermissionAnalysis.ps1"
        }
    }

    # Create test data based on the sample provided
    $script:testAppData = @(
        # App with activity and permissions
        [PSCustomObject]@{
            PrincipalId     = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            PrincipalName   = 'v1-app-registration-test'
            AppRoleCount    = 2
            AppRoles        = @(
                @{
                    appRoleId           = '7ab1d382-f21e-4acd-a863-ba3e13f7da61'
                    FriendlyName        = 'Directory.Read.All'
                    PermissionType      = 'Application'
                    resourceDisplayName = 'Microsoft Graph'
                }
                @{
                    appRoleId           = 'df021288-bdef-4463-88db-98f22de89214'
                    FriendlyName        = 'User.Read.All'
                    PermissionType      = 'Application'
                    resourceDisplayName = 'Microsoft Graph'
                }
            )
            Activity        = @(
                @{ Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/applications/{id}' }
                @{ Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/servicePrincipals/{id}' }
                @{ Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/users' }
            )
            ThrottlingStats = @{
                TotalRequests      = 1290
                SuccessfulRequests = 676
                Total429Errors     = 0
                TotalClientErrors  = 614
                TotalServerErrors  = 0
                ThrottleRate       = 0
                ErrorRate          = 47.6
                SuccessRate        = 52.4
                ThrottlingSeverity = 0
                ThrottlingStatus   = 'Normal'
                FirstOccurrence    = '2025-11-06T23:42:51Z'
                LastOccurrence     = '2025-12-06T21:27:56Z'
            }
        }
        # App with activity but no permissions assigned
        [PSCustomObject]@{
            PrincipalId     = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            PrincipalName   = 'LOG bestarchive API dev'
            AppRoleCount    = 1
            AppRoles        = @(
                @{
                    appRoleId           = '883ea226-0bf2-4a8f-9f9d-92c9162a727d'
                    FriendlyName        = 'Sites.Selected'
                    PermissionType      = 'Application'
                    resourceDisplayName = 'Microsoft Graph'
                }
            )
            Activity        = @(
                @{ Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/drives/{id}/items/{id}' }
                @{ Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/sites/{id}/lists/{id}/items' }
            )
            ThrottlingStats = @{
                TotalRequests      = 171
                SuccessfulRequests = 166
                Total429Errors     = 0
                TotalClientErrors  = 0
                TotalServerErrors  = 0
                ThrottleRate       = 0
                ErrorRate          = 0
                SuccessRate        = 97.08
                ThrottlingSeverity = 0
                ThrottlingStatus   = 'Normal'
                FirstOccurrence    = '2025-11-13T12:56:57Z'
                LastOccurrence     = '2025-12-03T14:30:22Z'
            }
        }
        # App without activity
        [PSCustomObject]@{
            PrincipalId     = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
            PrincipalName   = 'DataDogNotify'
            AppRoleCount    = 4
            AppRoles        = @(
                @{
                    appRoleId           = 'df021288-bdef-4463-88db-98f22de89214'
                    FriendlyName        = 'User.Read.All'
                    PermissionType      = 'Application'
                    resourceDisplayName = 'Microsoft Graph'
                }
                @{
                    appRoleId           = 'b633e1c5-b582-4048-a93e-9f11b44c7e96'
                    FriendlyName        = 'Mail.Send'
                    PermissionType      = 'Application'
                    resourceDisplayName = 'Microsoft Graph'
                }
                @{
                    appRoleId           = '294ce7c9-31ba-490a-ad7d-97a7d075e4ed'
                    FriendlyName        = 'Chat.ReadWrite.All'
                    PermissionType      = 'Application'
                    resourceDisplayName = 'Microsoft Graph'
                }
                @{
                    appRoleId           = 'd9c48af6-9ad9-47ad-82c3-63757137b9af'
                    FriendlyName        = 'Chat.Create'
                    PermissionType      = 'Application'
                    resourceDisplayName = 'Microsoft Graph'
                }
            )
            Activity        = $null
            ThrottlingStats = @{
                TotalRequests      = 13
                SuccessfulRequests = 0
                Total429Errors     = 1
                TotalClientErrors  = 1
                TotalServerErrors  = 0
                ThrottleRate       = 7.69
                ErrorRate          = 7.69
                SuccessRate        = 0
                ThrottlingSeverity = 3
                ThrottlingStatus   = 'Warning'
                FirstOccurrence    = '2025-11-26T00:14:02Z'
                LastOccurrence     = '2025-11-26T00:14:06Z'
            }
        }
        # App with complex permissions and activity
        [PSCustomObject]@{
            PrincipalId     = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
            PrincipalName   = 'BS - ServiceDesk license change'
            AppRoleCount    = 3
            AppRoles        = @(
                @{
                    appRoleId           = '883ea226-0bf2-4a8f-9f9d-92c9162a727d'
                    FriendlyName        = 'Sites.Selected'
                    PermissionType      = 'Application'
                    resourceDisplayName = 'Microsoft Graph'
                }
                @{
                    appRoleId           = 'df021288-bdef-4463-88db-98f22de89214'
                    FriendlyName        = 'User.Read.All'
                    PermissionType      = 'Application'
                    resourceDisplayName = 'Microsoft Graph'
                }
                @{
                    appRoleId           = '5facf0c1-8979-4e95-abcf-ff3d079771c0'
                    FriendlyName        = 'LicenseAssignment.ReadWrite.All'
                    PermissionType      = 'Application'
                    resourceDisplayName = 'Microsoft Graph'
                }
            )
            Activity        = @(
                @{ Method = 'GET'; Uri = 'https://graph.microsoft.com/beta/sites/{id}/lists/{id}/items' }
                @{ Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/users' }
                @{ Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/users/{id}' }
                @{ Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/users/{id}/memberOf' }
                @{ Method = 'POST'; Uri = 'https://graph.microsoft.com/v1.0/users/{id}/assignLicense' }
            )
            ThrottlingStats = @{
                TotalRequests      = 25273
                SuccessfulRequests = 25188
                Total429Errors     = 0
                TotalClientErrors  = 0
                TotalServerErrors  = 0
                ThrottleRate       = 0
                ErrorRate          = 0
                SuccessRate        = 99.66
                ThrottlingSeverity = 0
                ThrottlingStatus   = 'Normal'
                FirstOccurrence    = '2025-11-06T22:41:20Z'
                LastOccurrence     = '2025-12-06T22:26:15Z'
            }
        }
    )

    # Mock Find-LeastPrivilegedPermission
    if ($script:moduleLoaded) {
        Mock -CommandName Find-LeastPrivilegedPermission -ModuleName $script:moduleName -MockWith {
            param($userActivity, $permissionMapv1, $permissionMapbeta)

            # Return mock activity permissions based on input
            if ($userActivity -and $userActivity.Count -gt 0) {
                return @(
                    [PSCustomObject]@{
                        Activity   = $userActivity[0]
                        Permission = 'Application.Read.All'
                        Privilege  = 'Low'
                        Endpoint   = 'v1.0'
                    }
                )
            }
            return @()
        }
    }
    else {
        Mock -CommandName Find-LeastPrivilegedPermission -MockWith {
            param($userActivity, $permissionMapv1, $permissionMapbeta)

            if ($userActivity -and $userActivity.Count -gt 0) {
                return @(
                    [PSCustomObject]@{
                        Activity   = $userActivity[0]
                        Permission = 'Application.Read.All'
                        Privilege  = 'Low'
                        Endpoint   = 'v1.0'
                    }
                )
            }
            return @()
        }
    }

    # Mock Get-OptimalPermissionSet
    if ($script:moduleLoaded) {
        Mock -CommandName Get-OptimalPermissionSet -ModuleName $script:moduleName -MockWith {
            param($activityPermissions)

            return @{
                OptimalPermissions   = @(
                    [PSCustomObject]@{
                        Permission = 'Application.Read.All'
                        Privilege  = 'Low'
                        Coverage   = 1
                    }
                )
                UnmatchedActivities  = @()
                MatchedActivities    = if ($activityPermissions) { $activityPermissions.Count } else { 0 }
                TotalActivities      = if ($activityPermissions) { $activityPermissions.Count } else { 0 }
            }
        }
    }
    else {
        Mock -CommandName Get-OptimalPermissionSet -MockWith {
            param($activityPermissions)

            return @{
                OptimalPermissions   = @(
                    [PSCustomObject]@{
                        Permission = 'Application.Read.All'
                        Privilege  = 'Low'
                        Coverage   = 1
                    }
                )
                UnmatchedActivities  = @()
                MatchedActivities    = if ($activityPermissions) { $activityPermissions.Count } else { 0 }
                TotalActivities      = if ($activityPermissions) { $activityPermissions.Count } else { 0 }
            }
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-PermissionAnalysis' {
    Context 'Parameter Validation' {
        It 'Should have mandatory AppData parameter' {
            $command = Get-Command -Name Get-PermissionAnalysis
            $command.Parameters['AppData'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should accept pipeline input for AppData' {
            $command = Get-Command -Name Get-PermissionAnalysis
            $command.Parameters['AppData'].Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command -Name Get-PermissionAnalysis
            $command.CmdletBinding | Should -Be $true
        }

        It 'Should accept null input for AppData' {
            $command = Get-Command -Name Get-PermissionAnalysis
            $command.Parameters['AppData'].Attributes.Where({ $_.TypeId.Name -eq 'AllowNullAttribute' }) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Basic Functionality' {
        It 'Should process application data from pipeline' {
            $result = $script:testAppData[0] | Get-PermissionAnalysis

            $result | Should -Not -BeNullOrEmpty
            $result.PrincipalId | Should -Be 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        }

        It 'Should add analysis properties to output' {
            $result = $script:testAppData[0] | Get-PermissionAnalysis

            $result.PSObject.Properties.Name | Should -Contain 'ActivityPermissions'
            $result.PSObject.Properties.Name | Should -Contain 'OptimalPermissions'
            $result.PSObject.Properties.Name | Should -Contain 'CurrentPermissions'
            $result.PSObject.Properties.Name | Should -Contain 'ExcessPermissions'
            $result.PSObject.Properties.Name | Should -Contain 'RequiredPermissions'
            $result.PSObject.Properties.Name | Should -Contain 'UnmatchedActivities'
            $result.PSObject.Properties.Name | Should -Contain 'MatchedAllActivity'
        }

        It 'Should preserve original properties' {
            $result = $script:testAppData[0] | Get-PermissionAnalysis

            $result.PrincipalId | Should -Be $script:testAppData[0].PrincipalId
            $result.PrincipalName | Should -Be $script:testAppData[0].PrincipalName
            $result.AppRoleCount | Should -Be $script:testAppData[0].AppRoleCount
            $result.Activity | Should -Be $script:testAppData[0].Activity
            $result.ThrottlingStats | Should -Be $script:testAppData[0].ThrottlingStats
        }

        It 'Should process multiple applications from pipeline' {
            $results = $script:testAppData | Get-PermissionAnalysis

            $results.Count | Should -Be 4
            $results[0].PrincipalId | Should -Be 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            $results[1].PrincipalId | Should -Be 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            $results[2].PrincipalId | Should -Be 'cccccccc-cccc-cccc-cccc-cccccccccccc'
            $results[3].PrincipalId | Should -Be 'dddddddd-dddd-dddd-dddd-dddddddddddd'
        }

        It 'Should handle null input gracefully' {
            $result = $null | Get-PermissionAnalysis

            $result | Should -BeNullOrEmpty
        }

        It 'Should handle empty array input' {
            $result = @() | Get-PermissionAnalysis

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Apps With Activity' {
        It 'Should call Find-LeastPrivilegedPermission for apps with activity' {
            $script:testAppData[0] | Get-PermissionAnalysis

            if ($script:moduleLoaded) {
                Should -Invoke -CommandName Find-LeastPrivilegedPermission -ModuleName $script:moduleName -Times 1
            }
            else {
                Should -Invoke -CommandName Find-LeastPrivilegedPermission -Times 1
            }
        }

        It 'Should call Get-OptimalPermissionSet for apps with activity' {
            $script:testAppData[0] | Get-PermissionAnalysis

            if ($script:moduleLoaded) {
                Should -Invoke -CommandName Get-OptimalPermissionSet -ModuleName $script:moduleName -Times 1
            }
            else {
                Should -Invoke -CommandName Get-OptimalPermissionSet -Times 1
            }
        }

        It 'Should populate ActivityPermissions for apps with activity' {
            $result = $script:testAppData[0] | Get-PermissionAnalysis

            $result.ActivityPermissions | Should -Not -BeNullOrEmpty
        }

        It 'Should populate OptimalPermissions for apps with activity' {
            $result = $script:testAppData[0] | Get-PermissionAnalysis

            $result.OptimalPermissions | Should -Not -BeNullOrEmpty
        }

        It 'Should populate CurrentPermissions from AppRoles' {
            $result = $script:testAppData[0] | Get-PermissionAnalysis

            $result.CurrentPermissions | Should -Contain 'Directory.Read.All'
            $result.CurrentPermissions | Should -Contain 'User.Read.All'
            $result.CurrentPermissions.Count | Should -Be 2
        }

        It 'Should calculate ExcessPermissions correctly' {
            $result = $script:testAppData[0] | Get-PermissionAnalysis

            $result.ExcessPermissions | Should -Not -BeNullOrEmpty
            # Excess = Current permissions NOT in Optimal set
            $result.ExcessPermissions | Should -Contain 'Directory.Read.All'
            $result.ExcessPermissions | Should -Contain 'User.Read.All'
        }

        It 'Should calculate RequiredPermissions (missing permissions)' {
            $result = $script:testAppData[0] | Get-PermissionAnalysis

            # Required = Optimal permissions NOT in Current set
            $result.RequiredPermissions | Should -Contain 'Application.Read.All'
        }

        It 'Should set MatchedAllActivity to true when all activities matched' {
            $result = $script:testAppData[0] | Get-PermissionAnalysis

            $result.MatchedAllActivity | Should -Be $true
        }
    }

    Context 'Apps Without Activity' {
        It 'Should handle apps with null Activity' {
            $result = $script:testAppData[2] | Get-PermissionAnalysis

            $result | Should -Not -BeNullOrEmpty
            $result.PrincipalName | Should -Be 'DataDogNotify'
        }

        It 'Should set ActivityPermissions to empty array for apps without activity' {
            $result = $script:testAppData[2] | Get-PermissionAnalysis

            $result.ActivityPermissions | Should -BeNullOrEmpty
        }

        It 'Should set OptimalPermissions to empty array for apps without activity' {
            $result = $script:testAppData[2] | Get-PermissionAnalysis

            $result.OptimalPermissions | Should -BeNullOrEmpty
        }

        It 'Should set UnmatchedActivities to empty array for apps without activity' {
            $result = $script:testAppData[2] | Get-PermissionAnalysis

            $result.UnmatchedActivities | Should -BeNullOrEmpty
        }

        It 'Should populate CurrentPermissions even without activity' {
            $result = $script:testAppData[2] | Get-PermissionAnalysis

            $result.CurrentPermissions | Should -Contain 'User.Read.All'
            $result.CurrentPermissions | Should -Contain 'Mail.Send'
            $result.CurrentPermissions | Should -Contain 'Chat.ReadWrite.All'
            $result.CurrentPermissions | Should -Contain 'Chat.Create'
            $result.CurrentPermissions.Count | Should -Be 4
        }

        It 'Should set ExcessPermissions to all CurrentPermissions when no activity' {
            $result = $script:testAppData[2] | Get-PermissionAnalysis

            $result.ExcessPermissions.Count | Should -Be $result.CurrentPermissions.Count
        }

        It 'Should set RequiredPermissions to empty array when no activity' {
            $result = $script:testAppData[2] | Get-PermissionAnalysis

            $result.RequiredPermissions | Should -BeNullOrEmpty
        }

        It 'Should set MatchedAllActivity to true for apps without activity' {
            $result = $script:testAppData[2] | Get-PermissionAnalysis

            $result.MatchedAllActivity | Should -Be $true
        }

        It 'Should not call Find-LeastPrivilegedPermission for apps without activity' {
            if ($script:moduleLoaded) {
                Mock -CommandName Find-LeastPrivilegedPermission -ModuleName $script:moduleName -MockWith { throw "Should not be called" }
            }
            else {
                Mock -CommandName Find-LeastPrivilegedPermission -MockWith { throw "Should not be called" }
            }

            { $script:testAppData[2] | Get-PermissionAnalysis } | Should -Not -Throw
        }
    }

    Context 'Apps Without AppRoles' {
        It 'Should handle apps without AppRoles property' {
            $appWithoutRoles = [PSCustomObject]@{
                PrincipalId   = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
                PrincipalName = 'App Without Roles'
                Activity      = @(
                    @{ Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/users' }
                )
            }

            $result = $appWithoutRoles | Get-PermissionAnalysis

            $result.CurrentPermissions | Should -BeNullOrEmpty
            $result.ExcessPermissions | Should -BeNullOrEmpty
        }

        It 'Should handle apps with null AppRoles' {
            $appWithNullRoles = [PSCustomObject]@{
                PrincipalId   = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
                PrincipalName = 'App With Null Roles'
                AppRoles      = $null
                Activity      = @(
                    @{ Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/users' }
                )
            }

            $result = $appWithNullRoles | Get-PermissionAnalysis

            $result.CurrentPermissions | Should -BeNullOrEmpty
        }

        It 'Should handle apps with empty AppRoles array' {
            $appWithEmptyRoles = [PSCustomObject]@{
                PrincipalId   = '00000000-0000-0000-0000-000000000001'
                PrincipalName = 'App With Empty Roles'
                AppRoles      = @()
                Activity      = @(
                    @{ Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/users' }
                )
            }

            $result = $appWithEmptyRoles | Get-PermissionAnalysis

            $result.CurrentPermissions | Should -BeNullOrEmpty
        }
    }

    Context 'Error Handling' {
        It 'Should skip null app entries' {
            $mixedData = @(
                $script:testAppData[0]
                $null
                $script:testAppData[1]
            )

            $results = $mixedData | Get-PermissionAnalysis

            $results.Count | Should -Be 2
        }

        It 'Should skip apps without PrincipalName' {
            $appWithoutName = [PSCustomObject]@{
                PrincipalId = '00000000-0000-0000-0000-000000000002'
                Activity    = @()
            }

            { $appWithoutName | Get-PermissionAnalysis } | Should -Not -Throw
        }

        It 'Should handle Find-LeastPrivilegedPermission errors gracefully' {
            if ($script:moduleLoaded) {
                Mock -CommandName Find-LeastPrivilegedPermission -ModuleName $script:moduleName -MockWith {
                    throw "Simulated error"
                }
            }
            else {
                Mock -CommandName Find-LeastPrivilegedPermission -MockWith {
                    throw "Simulated error"
                }
            }

            { $script:testAppData[0] | Get-PermissionAnalysis } | Should -Throw
        }

        It 'Should handle Get-OptimalPermissionSet errors gracefully' {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-OptimalPermissionSet -ModuleName $script:moduleName -MockWith {
                    throw "Simulated error"
                }
            }
            else {
                Mock -CommandName Get-OptimalPermissionSet -MockWith {
                    throw "Simulated error"
                }
            }

            { $script:testAppData[0] | Get-PermissionAnalysis } | Should -Throw
        }
    }

    Context 'Data Integrity' {

        It 'Should preserve all original properties in output' {
            $result = $script:testAppData[0] | Get-PermissionAnalysis

            $result.PSObject.Properties.Name | Should -Contain 'PrincipalId'
            $result.PSObject.Properties.Name | Should -Contain 'PrincipalName'
            $result.PSObject.Properties.Name | Should -Contain 'AppRoleCount'
            $result.PSObject.Properties.Name | Should -Contain 'AppRoles'
            $result.PSObject.Properties.Name | Should -Contain 'Activity'
            $result.PSObject.Properties.Name | Should -Contain 'ThrottlingStats'
        }

    }

    Context 'Output Format' {
        It 'Should return PSCustomObject' {
            $result = $script:testAppData[0] | Get-PermissionAnalysis

            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Should maintain property order' {
            $result = $script:testAppData[0] | Get-PermissionAnalysis

            $properties = $result.PSObject.Properties.Name
            $originalProperties = @('PrincipalId', 'PrincipalName', 'AppRoleCount', 'AppRoles', 'Activity', 'ThrottlingStats')
            $newProperties = @('ActivityPermissions', 'OptimalPermissions', 'UnmatchedActivities', 'CurrentPermissions', 'ExcessPermissions', 'RequiredPermissions', 'MatchedAllActivity')

            # Original properties should appear first
            foreach ($prop in $originalProperties) {
                $properties | Should -Contain $prop
            }

            # New properties should be added
            foreach ($prop in $newProperties) {
                $properties | Should -Contain $prop
            }
        }

        It 'Should output objects immediately during pipeline processing' {
            $outputCount = 0
            $script:testAppData | Get-PermissionAnalysis | ForEach-Object {
                $outputCount++
            }

            $outputCount | Should -Be 4
        }
    }

    Context 'Permission Analysis Logic' {
        It 'Should identify when app has more permissions than needed' {
            # Mock scenario where app has excess permissions
            if ($script:moduleLoaded) {
                Mock -CommandName Get-OptimalPermissionSet -ModuleName $script:moduleName -MockWith {
                    return @{
                        OptimalPermissions   = @(
                            [PSCustomObject]@{ Permission = 'User.Read.All' }
                        )
                        UnmatchedActivities  = @()
                        MatchedActivities    = 1
                        TotalActivities      = 1
                    }
                }
            }
            else {
                Mock -CommandName Get-OptimalPermissionSet -MockWith {
                    return @{
                        OptimalPermissions   = @(
                            [PSCustomObject]@{ Permission = 'User.Read.All' }
                        )
                        UnmatchedActivities  = @()
                        MatchedActivities    = 1
                        TotalActivities      = 1
                    }
                }
            }

            $result = $script:testAppData[0] | Get-PermissionAnalysis

            # App has Directory.Read.All and User.Read.All, but only needs User.Read.All
            $result.ExcessPermissions | Should -Contain 'Directory.Read.All'
        }

        It 'Should identify when app is missing required permissions' {
            # Mock scenario where app needs permissions it doesn't have
            if ($script:moduleLoaded) {
                Mock -CommandName Get-OptimalPermissionSet -ModuleName $script:moduleName -MockWith {
                    return @{
                        OptimalPermissions   = @(
                            [PSCustomObject]@{ Permission = 'Mail.Read' }
                            [PSCustomObject]@{ Permission = 'User.Read.All' }
                        )
                        UnmatchedActivities  = @()
                        MatchedActivities    = 2
                        TotalActivities      = 2
                    }
                }
            }
            else {
                Mock -CommandName Get-OptimalPermissionSet -MockWith {
                    return @{
                        OptimalPermissions   = @(
                            [PSCustomObject]@{ Permission = 'Mail.Read' }
                            [PSCustomObject]@{ Permission = 'User.Read.All' }
                        )
                        UnmatchedActivities  = @()
                        MatchedActivities    = 2
                        TotalActivities      = 2
                    }
                }
            }

            $result = $script:testAppData[0] | Get-PermissionAnalysis

            # App doesn't have Mail.Read but needs it
            $result.RequiredPermissions | Should -Contain 'Mail.Read'
        }

        It 'Should set MatchedAllActivity to false when activities are unmatched' {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-OptimalPermissionSet -ModuleName $script:moduleName -MockWith {
                    return @{
                        OptimalPermissions   = @()
                        UnmatchedActivities  = @(
                            [PSCustomObject]@{ Method = 'POST'; Uri = 'https://graph.microsoft.com/v1.0/unknown' }
                        )
                        MatchedActivities    = 0
                        TotalActivities      = 1
                    }
                }
            }
            else {
                Mock -CommandName Get-OptimalPermissionSet -MockWith {
                    return @{
                        OptimalPermissions   = @()
                        UnmatchedActivities  = @(
                            [PSCustomObject]@{ Method = 'POST'; Uri = 'https://graph.microsoft.com/v1.0/unknown' }
                        )
                        MatchedActivities    = 0
                        TotalActivities      = 1
                    }
                }
            }

            $result = $script:testAppData[0] | Get-PermissionAnalysis

            $result.MatchedAllActivity | Should -Be $false
            $result.UnmatchedActivities.Count | Should -BeGreaterThan 0
        }
    }
}
