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
        # Fallback: dot source the function directly for testing
        $publicFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Public" -Filter "Assert-LPMSGraph.ps1" -ErrorAction SilentlyContinue

        if ($publicFunction) {
            . $publicFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find Assert-LPMSGraph.ps1"
        }
    }

    # Mock data for successful authentication
    $script:mockTokens = @(
        [PSCustomObject]@{
            Service  = 'LogAnalytics'
            TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        }
        [PSCustomObject]@{
            Service  = 'Graph'
            TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        }
        [PSCustomObject]@{
            Service  = 'Azure'
            TenantId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        }
    )

    # Mock data for Azure AD Premium SKUs
    $script:mockSkus = @(
        [PSCustomObject]@{
            skuPartNumber = 'AAD_PREMIUM_P1'
            servicePlans  = @(
                [PSCustomObject]@{
                    servicePlanName = 'AAD_PREMIUM'
                }
            )
        }
        [PSCustomObject]@{
            skuPartNumber = 'AAD_PREMIUM_P2'
            servicePlans  = @(
                [PSCustomObject]@{
                    servicePlanName = 'AAD_PREMIUM'
                }
            )
        }
    )

    # Mock data for diagnostic settings
    $script:mockDiagnosticSettings = @(
        [PSCustomObject]@{
            name       = 'diag-setting-1'
            properties = [PSCustomObject]@{
                logs        = @('MicrosoftGraphActivityLogs', 'SignInLogs')
                workspaceId = '/subscriptions/sub-id/resourceGroups/rg-name/providers/Microsoft.OperationalInsights/workspaces/workspace-name'
            }
        }
    )

    # Mock data for Log Analytics query response
    $script:mockLogAnalyticsResponse = [PSCustomObject]@{
        tables = @(
            [PSCustomObject]@{
                rows = @(
                    @('2025-12-18T10:00:00Z', 'GET', '/v1.0/users', '200', 'app-id')
                )
            }
        )
    }

    # Mock data for applications response
    $script:mockApplications = @(
        [PSCustomObject]@{
            id          = 'app-id-1'
            displayName = 'Test Application 1'
        }
    )
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Assert-LPMSGraph' {
    Context 'Parameter Validation' {
        It 'Should have CmdletBinding attribute' {
            $command = Get-Command -Name Assert-LPMSGraph
            $command.CmdletBinding | Should -Be $true
        }

        It 'Should not have any mandatory parameters' {
            $command = Get-Command -Name Assert-LPMSGraph
            $mandatoryParams = $command.Parameters.Values | Where-Object { $_.Attributes.Mandatory -eq $true }
            $mandatoryParams | Should -BeNullOrEmpty
        }
    }

    Context 'Complete Success Scenario' {
        BeforeEach {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $script:mockTokens
                }
                Mock -CommandName Invoke-EntraRequest -ModuleName $script:moduleName -MockWith {
                    param($Service, $Path, $Method)
                    if ($Path -eq '/subscribedSkus') {
                        return $script:mockSkus
                    }
                    elseif ($Path -match 'diagnosticSettings') {
                        return $script:mockDiagnosticSettings
                    }
                    elseif ($Path -match '/query$') {
                        return $script:mockLogAnalyticsResponse
                    }
                    elseif ($Path -eq '/applications') {
                        return $script:mockApplications
                    }
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $script:mockTokens
                }
                Mock -CommandName Invoke-EntraRequest -MockWith {
                    param($Service, $Path, $Method)
                    if ($Path -eq '/subscribedSkus') {
                        return $script:mockSkus
                    }
                    elseif ($Path -match 'diagnosticSettings') {
                        return $script:mockDiagnosticSettings
                    }
                    elseif ($Path -match '/query$') {
                        return $script:mockLogAnalyticsResponse
                    }
                    elseif ($Path -eq '/applications') {
                        return $script:mockApplications
                    }
                }
            }
        }

        It 'Should return PSCustomObject' {
            $result = Assert-LPMSGraph
            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Should include TenantId in result' {
            $result = Assert-LPMSGraph
            $result.TenantId | Should -Be 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        }

        It 'Should include Timestamp in result' {
            $result = Assert-LPMSGraph
            $result.Timestamp | Should -BeOfType [datetime]
        }

        It 'Should have all 5 validation checks' {
            $result = Assert-LPMSGraph
            $result.Checks.Count | Should -Be 5
        }
    }

    Context 'Service Connectivity Check' {
        It 'Should pass when all required services are connected' {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $script:mockTokens
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $script:mockTokens
                }
            }

            $result = Assert-LPMSGraph
            $connectivityCheck = $result.Checks | Where-Object { $_.Name -eq 'Entra Service Connectivity' }
            $connectivityCheck.Status | Should -Be 'Passed'
        }

        It 'Should fail when LogAnalytics service is missing' {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $script:mockTokens | Where-Object { $_.Service -ne 'LogAnalytics' }
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $script:mockTokens | Where-Object { $_.Service -ne 'LogAnalytics' }
                }
            }

            $result = Assert-LPMSGraph
            $connectivityCheck = $result.Checks | Where-Object { $_.Name -eq 'Entra Service Connectivity' }
            $connectivityCheck.Status | Should -Be 'Failed'
            $connectivityCheck.Message | Should -Match 'LogAnalytics'
        }

        It 'Should fail when Graph service is missing' {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $script:mockTokens | Where-Object { $_.Service -ne 'Graph' }
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $script:mockTokens | Where-Object { $_.Service -ne 'Graph' }
                }
            }

            $result = Assert-LPMSGraph
            $connectivityCheck = $result.Checks | Where-Object { $_.Name -eq 'Entra Service Connectivity' }
            $connectivityCheck.Status | Should -Be 'Failed'
            $connectivityCheck.Message | Should -Match 'Graph'
        }

        It 'Should fail when Azure service is missing' {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $script:mockTokens | Where-Object { $_.Service -ne 'Azure' }
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $script:mockTokens | Where-Object { $_.Service -ne 'Azure' }
                }
            }

            $result = Assert-LPMSGraph
            $connectivityCheck = $result.Checks | Where-Object { $_.Name -eq 'Entra Service Connectivity' }
            $connectivityCheck.Status | Should -Be 'Failed'
            $connectivityCheck.Message | Should -Match 'Azure'
        }

        It 'Should fail when multiple services are missing' {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $script:mockTokens | Where-Object { $_.Service -eq 'Graph' }
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $script:mockTokens | Where-Object { $_.Service -eq 'Graph' }
                }
            }

            $result = Assert-LPMSGraph
            $connectivityCheck = $result.Checks | Where-Object { $_.Name -eq 'Entra Service Connectivity' }
            $connectivityCheck.Status | Should -Be 'Failed'
            $connectivityCheck.Message | Should -Match 'LogAnalytics'
            $connectivityCheck.Message | Should -Match 'Azure'
        }

        It 'Should handle Get-EntraToken exception gracefully' {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    throw "Authentication failed"
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    throw "Authentication failed"
                }
            }

            $result = Assert-LPMSGraph
            $connectivityCheck = $result.Checks | Where-Object { $_.Name -eq 'Entra Service Connectivity' }
            $connectivityCheck.Status | Should -Be 'Failed'
            $connectivityCheck.Error | Should -Not -BeNullOrEmpty
        }
    }







    Context 'Microsoft Graph API Permissions Check' {
        BeforeEach {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $script:mockTokens
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $script:mockTokens
                }
            }
        }

        It 'Should include required permission information in failure message' {
            if ($script:moduleLoaded) {
                Mock -CommandName Invoke-EntraRequest -ModuleName $script:moduleName -MockWith {
                    param($Path, $Service)
                    if ($Path -eq '/applications' -and $Service -eq 'Graph') {
                        throw "Access denied"
                    }
                }
            }
            else {
                Mock -CommandName Invoke-EntraRequest -MockWith {
                    param($Path, $Service)
                    if ($Path -eq '/applications' -and $Service -eq 'Graph') {
                        throw "Access denied"
                    }
                }
            }

            $result = Assert-LPMSGraph
            $graphCheck = $result.Checks | Where-Object { $_.Name -eq 'Microsoft Graph API Permissions' }
            $graphCheck.Message | Should -Match 'Application.Read.All'
        }
    }

    Context 'Check Result Structure' {
        BeforeEach {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $script:mockTokens
                }
                Mock -CommandName Invoke-EntraRequest -ModuleName $script:moduleName -MockWith {
                    return @()
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $script:mockTokens
                }
                Mock -CommandName Invoke-EntraRequest -MockWith {
                    return @()
                }
            }
        }

        It 'Should have Name property in each check' {
            $result = Assert-LPMSGraph
            foreach ($check in $result.Checks) {
                $check.PSObject.Properties.Name | Should -Contain 'Name'
                $check.Name | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should have Status property in each check' {
            $result = Assert-LPMSGraph
            foreach ($check in $result.Checks) {
                $check.PSObject.Properties.Name | Should -Contain 'Status'
                $check.Status | Should -BeIn @('Passed', 'Failed')
            }
        }

        It 'Should have Message property in each check' {
            $result = Assert-LPMSGraph
            foreach ($check in $result.Checks) {
                $check.PSObject.Properties.Name | Should -Contain 'Message'
                $check.Message | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should have Error property in each check' {
            $result = Assert-LPMSGraph
            foreach ($check in $result.Checks) {
                $check.PSObject.Properties.Name | Should -Contain 'Error'
            }
        }
    }

    Context 'Overall Status Logic' {
        BeforeEach {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $script:mockTokens
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $script:mockTokens
                }
            }
        }

        It 'Should set OverallStatus to Failed when any check fails' {
            if ($script:moduleLoaded) {
                Mock -CommandName Invoke-EntraRequest -ModuleName $script:moduleName -MockWith {
                    param($Path)
                    if ($Path -eq '/subscribedSkus') {
                        return @() # No licenses - will fail
                    }
                    return @()
                }
            }
            else {
                Mock -CommandName Invoke-EntraRequest -MockWith {
                    param($Path)
                    if ($Path -eq '/subscribedSkus') {
                        return @() # No licenses - will fail
                    }
                    return @()
                }
            }

            $result = Assert-LPMSGraph
            $result.OverallStatus | Should -Be 'Failed'
        }

        It 'Should maintain Failed status even if later checks pass' {
            if ($script:moduleLoaded) {
                Mock -CommandName Invoke-EntraRequest -ModuleName $script:moduleName -MockWith {
                    param($Path, $Service)
                    if ($Path -eq '/subscribedSkus') {
                        return @() # Fail license check
                    }
                    elseif ($Path -eq '/applications') {
                        return $script:mockApplications # Pass Graph check
                    }
                    return @()
                }
            }
            else {
                Mock -CommandName Invoke-EntraRequest -MockWith {
                    param($Path, $Service)
                    if ($Path -eq '/subscribedSkus') {
                        return @() # Fail license check
                    }
                    elseif ($Path -eq '/applications') {
                        return $script:mockApplications # Pass Graph check
                    }
                    return @()
                }
            }

            $result = Assert-LPMSGraph
            $result.OverallStatus | Should -Be 'Failed'
        }
    }

    Context 'Verbose and Debug Messages' {
        BeforeEach {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $script:mockTokens
                }
                Mock -CommandName Invoke-EntraRequest -ModuleName $script:moduleName -MockWith {
                    return $script:mockSkus
                }
                Mock -CommandName Write-PSFMessage -ModuleName $script:moduleName -MockWith { }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $script:mockTokens
                }
                Mock -CommandName Invoke-EntraRequest -MockWith {
                    return $script:mockSkus
                }
                Mock -CommandName Write-PSFMessage -MockWith { }
            }
        }

        It 'Should write verbose message when starting validation' {
            $result = Assert-LPMSGraph

            if ($script:moduleLoaded) {
                Should -Invoke -CommandName Write-PSFMessage -ModuleName $script:moduleName -ParameterFilter {
                    $Level -eq 'Verbose' -and $Message -match 'Starting.*prerequisites validation'
                }
            }
            else {
                Should -Invoke -CommandName Write-PSFMessage -ParameterFilter {
                    $Level -eq 'Verbose' -and $Message -match 'Starting.*prerequisites validation'
                }
            }
        }
    }

    Context 'Edge Cases and Special Scenarios' {
        It 'Should handle null token gracefully' {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $null
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $null
                }
            }

            $result = Assert-LPMSGraph
            $result | Should -Not -BeNullOrEmpty
            $result.TenantId | Should -BeNullOrEmpty
        }

        It 'Should handle empty SKU list' {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $script:mockTokens
                }
                Mock -CommandName Invoke-EntraRequest -ModuleName $script:moduleName -MockWith {
                    param($Path)
                    if ($Path -eq '/subscribedSkus') {
                        return @()
                    }
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $script:mockTokens
                }
                Mock -CommandName Invoke-EntraRequest -MockWith {
                    param($Path)
                    if ($Path -eq '/subscribedSkus') {
                        return @()
                    }
                }
            }

            $result = Assert-LPMSGraph
            $licenseCheck = $result.Checks | Where-Object { $_.Name -eq 'Azure AD Premium License' }
            $licenseCheck.Status | Should -Be 'Failed'
        }

        It 'Should continue checking even after first failure' {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $script:mockTokens[0] # Only one service
                }
                Mock -CommandName Invoke-EntraRequest -ModuleName $script:moduleName -MockWith {
                    return @()
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $script:mockTokens[0] # Only one service
                }
                Mock -CommandName Invoke-EntraRequest -MockWith {
                    return @()
                }
            }

            $result = Assert-LPMSGraph
            # Should still have all 5 checks even though first one fails
            $result.Checks.Count | Should -Be 5
        }
    }

    Context 'Output Format and Display' {
        BeforeEach {
            if ($script:moduleLoaded) {
                Mock -CommandName Get-EntraToken -ModuleName $script:moduleName -MockWith {
                    return $script:mockTokens
                }
                Mock -CommandName Invoke-EntraRequest -ModuleName $script:moduleName -MockWith {
                    return $script:mockSkus
                }
            }
            else {
                Mock -CommandName Get-EntraToken -MockWith {
                    return $script:mockTokens
                }
                Mock -CommandName Invoke-EntraRequest -MockWith {
                    return $script:mockSkus
                }
            }
        }

        It 'Should be convertible to JSON' {
            $result = Assert-LPMSGraph
            { $result | ConvertTo-Json -Depth 5 } | Should -Not -Throw
        }

        It 'Should support property selection' {
            $result = Assert-LPMSGraph
            $selected = $result | Select-Object -Property OverallStatus, TenantId
            $selected.OverallStatus | Should -Not -BeNullOrEmpty
        }

        It 'Should support filtering Checks array' {
            $result = Assert-LPMSGraph
            $failedChecks = $result.Checks | Where-Object { $_.Status -eq 'Failed' }
            $failedChecks | Should -Not -BeNull
        }

        It 'Should support Format-Table on Checks' {
            $result = Assert-LPMSGraph
            { $result.Checks | Format-Table Name, Status, Message -AutoSize | Out-String } | Should -Not -Throw
        }
    }
}
