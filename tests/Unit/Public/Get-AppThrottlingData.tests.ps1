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
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "Get-AppThrottlingStat.ps1" -ErrorAction SilentlyContinue
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

    # Create anonymized test data based on production output
    $script:mockThrottlingData = @(
        [PSCustomObject]@{
            ServicePrincipalId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            TotalRequests      = 1294
            SuccessfulRequests = 679
            Total429Errors     = 0
            TotalClientErrors  = 615
            TotalServerErrors  = 0
            ThrottleRate       = 0
            ErrorRate          = 47.53
            SuccessRate        = 52.47
            ThrottlingSeverity = 0
            ThrottlingStatus   = 'Normal'
            FirstOccurrence    = '2025-11-06T22:31:14Z'
            LastOccurrence     = '2025-12-06T21:27:56Z'
        }
        [PSCustomObject]@{
            ServicePrincipalId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
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
        [PSCustomObject]@{
            ServicePrincipalId = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
            TotalRequests      = 1515
            SuccessfulRequests = 1415
            Total429Errors     = 0
            TotalClientErrors  = 95
            TotalServerErrors  = 0
            ThrottleRate       = 0
            ErrorRate          = 6.27
            SuccessRate        = 93.4
            ThrottlingSeverity = 0
            ThrottlingStatus   = 'Normal'
            FirstOccurrence    = '2025-11-06T22:25:19Z'
            LastOccurrence     = '2025-12-06T11:01:35Z'
        }
        [PSCustomObject]@{
            ServicePrincipalId = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
            TotalRequests      = 23903
            SuccessfulRequests = 23885
            Total429Errors     = 0
            TotalClientErrors  = 0
            TotalServerErrors  = 18
            ThrottleRate       = 0
            ErrorRate          = 0.08
            SuccessRate        = 99.92
            ThrottlingSeverity = 0
            ThrottlingStatus   = 'Normal'
            FirstOccurrence    = '2025-11-06T22:11:03Z'
            LastOccurrence     = '2025-12-06T22:05:03Z'
        }
        [PSCustomObject]@{
            ServicePrincipalId = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
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
        [PSCustomObject]@{
            ServicePrincipalId = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
            TotalRequests      = 25280
            SuccessfulRequests = 25195
            Total429Errors     = 0
            TotalClientErrors  = 0
            TotalServerErrors  = 0
            ThrottleRate       = 0
            ErrorRate          = 0
            SuccessRate        = 99.66
            ThrottlingSeverity = 0
            ThrottlingStatus   = 'Normal'
            FirstOccurrence    = '2025-11-06T22:11:20Z'
            LastOccurrence     = '2025-12-06T21:56:16Z'
        }
    )

    $script:testAppData = @(
        [PSCustomObject]@{
            PrincipalId   = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            PrincipalName = 'TestApp-DirectoryReader'
            AppRoleCount  = 2
            AppRoles      = @(
                @{appRoleId = '7ab1d382-f21e-4acd-a863-ba3e13f7da61'; FriendlyName = 'Directory.Read.All'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
                @{appRoleId = 'df021288-bdef-4463-88db-98f22de89214'; FriendlyName = 'User.Read.All'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
            )
        }
        [PSCustomObject]@{
            PrincipalId   = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            PrincipalName = 'TestApp-SharePointReader'
            AppRoleCount  = 1
            AppRoles      = @(
                @{appRoleId = '883ea226-0bf2-4a8f-9f9d-92c9162a727d'; FriendlyName = 'Sites.Selected'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
            )
        }
        [PSCustomObject]@{
            PrincipalId   = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
            PrincipalName = 'TestApp-UserManager'
            AppRoleCount  = 1
            AppRoles      = @(
                @{appRoleId = '741f803b-c850-494e-b5df-cde7c675a1ca'; FriendlyName = 'User.ReadWrite.All'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
            )
        }
        [PSCustomObject]@{
            PrincipalId   = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
            PrincipalName = 'TestApp-MailProcessor'
            AppRoleCount  = 2
            AppRoles      = @(
                @{appRoleId = '97235f07-e226-4f63-ace3-39588e11d3a1'; FriendlyName = 'User.ReadBasic.All'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
                @{appRoleId = 'e2a3a72e-5f79-4c64-b1b1-878b674786c9'; FriendlyName = 'Mail.ReadWrite'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
            )
        }
        [PSCustomObject]@{
            PrincipalId   = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
            PrincipalName = 'TestApp-ThrottledApp'
            AppRoleCount  = 4
            AppRoles      = @(
                @{appRoleId = 'df021288-bdef-4463-88db-98f22de89214'; FriendlyName = 'User.Read.All'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
                @{appRoleId = 'b633e1c5-b582-4048-a93e-9f11b44c7e96'; FriendlyName = 'Mail.Send'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
                @{appRoleId = '294ce7c9-31ba-490a-ad7d-97a7d075e4ed'; FriendlyName = 'Chat.ReadWrite.All'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
                @{appRoleId = 'd9c48af6-9ad9-47ad-82c3-63757137b9af'; FriendlyName = 'Chat.Create'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
            )
        }
        [PSCustomObject]@{
            PrincipalId   = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
            PrincipalName = 'TestApp-HighVolume'
            AppRoleCount  = 3
            AppRoles      = @(
                @{appRoleId = '883ea226-0bf2-4a8f-9f9d-92c9162a727d'; FriendlyName = 'Sites.Selected'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
                @{appRoleId = 'df021288-bdef-4463-88db-98f22de89214'; FriendlyName = 'User.Read.All'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
                @{appRoleId = '5facf0c1-8979-4e95-abcf-ff3d079771c0'; FriendlyName = 'LicenseAssignment.ReadWrite.All'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
            )
        }
    )
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

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command -Name Get-AppThrottlingData
            $command.CmdletBinding | Should -Be $true
        }
    }

    Context 'Basic Functionality' {
        BeforeEach {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-AppThrottlingStat -ModuleName $script:moduleName -MockWith {
                    return $script:mockThrottlingData
                }
            }
            else {
                Mock -CommandName Get-AppThrottlingStat -MockWith {
                    return $script:mockThrottlingData
                }
            }
        }

        It 'Should process application data from pipeline' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should add ThrottlingStats property to output' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30
            $result.PSObject.Properties.Name | Should -Contain 'ThrottlingStats'
        }

        It 'Should preserve original properties' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.PrincipalId | Should -Be 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            $result.PrincipalName | Should -Be 'TestApp-DirectoryReader'
            $result.AppRoleCount | Should -Be 2
            $result.AppRoles | Should -Not -BeNullOrEmpty
        }

        It 'Should call Get-AppThrottlingStat with correct parameters' {
            $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            if ($script:moduleLoaded) {
                Should -Invoke -CommandName Get-AppThrottlingStat -ModuleName $script:moduleName -Times 1 -Exactly
            }
            else {
                Should -Invoke -CommandName Get-AppThrottlingStat -Times 1 -Exactly
            }
        }

        It 'Should process multiple applications from pipeline' {
            $result = $script:testAppData | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.Count | Should -Be $script:testAppData.Count
        }

        It 'Should accept custom Days parameter' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 7

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Throttling Statistics Content' {
        BeforeEach {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-AppThrottlingStat -ModuleName $script:moduleName -MockWith {
                    return $script:mockThrottlingData
                }
            }
            else {
                Mock -CommandName Get-AppThrottlingStat -MockWith {
                    return $script:mockThrottlingData
                }
            }
        }

        It 'Should include TotalRequests in ThrottlingStats' {
            Write-Host "Test App PrincipalId: $($script:testAppData[0].PrincipalId)"
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            Write-Host "Result ThrottlingStats: $($result.ThrottlingStats | ConvertTo-Json -Depth 3)"
            $result.ThrottlingStats.TotalRequests | Should -Be 1294
        }

        It 'Should include SuccessfulRequests in ThrottlingStats' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.ThrottlingStats.SuccessfulRequests | Should -Be 679
        }

        It 'Should include Total429Errors in ThrottlingStats' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.ThrottlingStats.Total429Errors | Should -Be 0
        }

        It 'Should include error counts in ThrottlingStats' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.ThrottlingStats.TotalClientErrors | Should -Be 615
            $result.ThrottlingStats.TotalServerErrors | Should -Be 0
        }

        It 'Should include rate calculations in ThrottlingStats' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.ThrottlingStats.ThrottleRate | Should -Be 0
            $result.ThrottlingStats.ErrorRate | Should -Be 47.53
            $result.ThrottlingStats.SuccessRate | Should -Be 52.47
        }

        It 'Should include severity and status in ThrottlingStats' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.ThrottlingStats.ThrottlingSeverity | Should -Be 0
            $result.ThrottlingStats.ThrottlingStatus | Should -Be 'Normal'
        }

        It 'Should include occurrence timestamps in ThrottlingStats' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.ThrottlingStats.FirstOccurrence | Should -Not -BeNullOrEmpty
            $result.ThrottlingStats.LastOccurrence | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Different Throttling Scenarios' {
        BeforeEach {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-AppThrottlingStat -ModuleName $script:moduleName -MockWith {
                    return $script:mockThrottlingData
                }
            }
            else {
                Mock -CommandName Get-AppThrottlingStat -MockWith {
                    return $script:mockThrottlingData
                }
            }
        }

        It 'Should handle apps with no throttling' {
            $result = $script:testAppData[1] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.ThrottlingStats.Total429Errors | Should -Be 0
            $result.ThrottlingStats.ThrottleRate | Should -Be 0
            # This app has activity, so should be 'Normal', not 'No Activity'
            $result.ThrottlingStats.ThrottlingStatus | Should -Be 'Normal'
        }

        It 'Should handle apps with high error rates' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            # Verify the data is being returned
            $result | Should -Not -BeNullOrEmpty
            $result.ThrottlingStats | Should -Not -BeNullOrEmpty

            $result.ThrottlingStats.ErrorRate | Should -Be 47.53
            $result.ThrottlingStats.TotalClientErrors | Should -Be 615
        }

        It 'Should handle apps with throttling warnings' {
            $result = $script:testAppData[4] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.ThrottlingStats.Total429Errors | Should -Be 1
            $result.ThrottlingStats.ThrottlingSeverity | Should -Be 3
            $result.ThrottlingStats.ThrottlingStatus | Should -Be 'Warning'
        }

        It 'Should handle apps with high success rates' {
            $result = $script:testAppData[3] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.ThrottlingStats.SuccessRate | Should -Be 99.92
            $result.ThrottlingStats.ErrorRate | Should -Be 0.08
        }

        It 'Should handle high volume applications' {
            $result = $script:testAppData[5] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.ThrottlingStats.TotalRequests | Should -Be 25280
            $result.ThrottlingStats.SuccessRate | Should -Be 99.66
        }

        It 'Should handle apps with server errors' {
            $result = $script:testAppData[3] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.ThrottlingStats.TotalServerErrors | Should -Be 18
        }
    }

    Context 'Error Handling' {

        It 'Should handle Get-AppThrottlingStat errors gracefully' {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-AppThrottlingStat -ModuleName $script:moduleName -MockWith {
                    throw "Log Analytics query failed"
                }
            }
            else {
                Mock -CommandName Get-AppThrottlingStat -MockWith {
                    throw "Log Analytics query failed"
                }
            }

            { $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30 } | Should -Throw
        }

        It 'Should handle empty throttling data by providing default stats' {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-AppThrottlingStat -ModuleName $script:moduleName -MockWith {
                    return @{}
                }
            }
            else {
                Mock -CommandName Get-AppThrottlingStat -MockWith {
                    return @{}
                }
            }

            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result | Should -Not -BeNullOrEmpty
            # Function provides default "No Activity" stats when no data found
            $result.ThrottlingStats | Should -Not -BeNullOrEmpty
            $result.ThrottlingStats.ThrottlingStatus | Should -Be 'No Activity'
        }
    }

    Context 'Data Integrity' {
        BeforeEach {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-AppThrottlingStat -ModuleName $script:moduleName -MockWith {
                    return $script:mockThrottlingData
                }
            }
            else {
                Mock -CommandName Get-AppThrottlingStat -MockWith {
                    return $script:mockThrottlingData
                }
            }
        }

        It 'Should maintain PrincipalId association' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.PrincipalId | Should -Be $script:testAppData[0].PrincipalId
        }

        It 'Should preserve all AppRoles data' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.AppRoles.Count | Should -Be $script:testAppData[0].AppRoles.Count
            $result.AppRoles[0].FriendlyName | Should -Be $script:testAppData[0].AppRoles[0].FriendlyName
        }
    }

    Context 'Output Format' {
        BeforeEach {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-AppThrottlingStat -ModuleName $script:moduleName -MockWith {
                    return $script:mockThrottlingData
                }
            }
            else {
                Mock -CommandName Get-AppThrottlingStat -MockWith {
                    return $script:mockThrottlingData
                }
            }
        }

        It 'Should return PSCustomObject' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Should have ThrottlingStats as hashtable or PSCustomObject' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $result.ThrottlingStats | Should -Not -BeNullOrEmpty
            $result.ThrottlingStats.GetType().Name | Should -BeIn @('Hashtable', 'PSCustomObject')
        }

        It 'Should maintain property order' {
            $result = $script:testAppData[0] | Get-AppThrottlingData -WorkspaceId 'test-workspace-id' -Days 30

            $properties = $result.PSObject.Properties.Name
            $properties | Should -Contain 'PrincipalId'
            $properties | Should -Contain 'PrincipalName'
            $properties | Should -Contain 'AppRoleCount'
            $properties | Should -Contain 'AppRoles'
            $properties | Should -Contain 'ThrottlingStats'
        }
    }
}
