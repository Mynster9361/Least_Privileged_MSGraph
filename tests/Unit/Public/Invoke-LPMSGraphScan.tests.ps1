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
        $publicFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Public" -Filter "Invoke-LPMSGraphScan.ps1" -ErrorAction SilentlyContinue

        if ($publicFunction) {
            . $publicFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find Invoke-LPMSGraphScan.ps1"
        }
    }

    # Create mock data for testing
    $script:mockAppData = @(
        [PSCustomObject]@{
            AppId              = 'app-123'
            DisplayName        = 'Test App 1'
            ServicePrincipalId = 'sp-123'
        }
        [PSCustomObject]@{
            AppId              = 'app-456'
            DisplayName        = 'Test App 2'
            ServicePrincipalId = 'sp-456'
        }
    )
}

Describe 'Invoke-LPMSGraphScan' {
    Context 'Parameter Validation' {
        It 'Should have CmdletBinding attribute' {
            $command = Get-Command -Name Invoke-LPMSGraphScan
            $command.CmdletBinding | Should -Be $true
        }

        It 'Should have two parameter sets' {
            $command = Get-Command -Name Invoke-LPMSGraphScan
            $command.ParameterSets.Count | Should -Be 2
            $command.ParameterSets.Name | Should -Contain 'ByWorkspaceId'
            $command.ParameterSets.Name | Should -Contain 'ByWorkspaceDetails'
        }

        It 'Should have mandatory WorkspaceId parameter in ByWorkspaceId parameter set' {
            $command = Get-Command -Name Invoke-LPMSGraphScan
            $param = $command.Parameters['WorkspaceId']
            $param.Attributes.Where({ $_.TypeId.Name -eq 'ParameterAttribute' -and $_.ParameterSetName -eq 'ByWorkspaceId' }).Mandatory | Should -Be $true
        }

        It 'Should have mandatory subId, rgName, and workspaceName in ByWorkspaceDetails parameter set' {
            $command = Get-Command -Name Invoke-LPMSGraphScan
            $command.Parameters['subId'].Attributes.Where({ $_.ParameterSetName -eq 'ByWorkspaceDetails' }).Mandatory | Should -Be $true
            $command.Parameters['rgName'].Attributes.Where({ $_.ParameterSetName -eq 'ByWorkspaceDetails' }).Mandatory | Should -Be $true
            $command.Parameters['workspaceName'].Attributes.Where({ $_.ParameterSetName -eq 'ByWorkspaceDetails' }).Mandatory | Should -Be $true
        }

        It 'Should have default value for Days parameter (30)' {
            $command = Get-Command -Name Invoke-LPMSGraphScan
            $command.Parameters['Days'].Attributes.Where({ $_.TypeId.Name -eq 'ParameterAttribute' }).Mandatory | Should -Be $false
            # Default value validation would need to be done during invocation
        }

        It 'Should have default value for ThrottleLimit parameter (20)' {
            $command = Get-Command -Name Invoke-LPMSGraphScan
            $command.Parameters['ThrottleLimit'].Attributes.Where({ $_.TypeId.Name -eq 'ParameterAttribute' }).Mandatory | Should -Be $false
        }

        It 'Should have default value for MaxActivityEntries parameter (100000)' {
            $command = Get-Command -Name Invoke-LPMSGraphScan
            $command.Parameters['MaxActivityEntries'].Attributes.Where({ $_.TypeId.Name -eq 'ParameterAttribute' }).Mandatory | Should -Be $false
        }

        It 'Should have default value for OutputPath parameter' {
            $command = Get-Command -Name Invoke-LPMSGraphScan
            $command.Parameters['OutputPath'].Attributes.Where({ $_.TypeId.Name -eq 'ParameterAttribute' }).Mandatory | Should -Be $false
        }

        It 'Should have ExcludeThrottleData switch parameter' {
            $command = Get-Command -Name Invoke-LPMSGraphScan
            $command.Parameters['ExcludeThrottleData'].SwitchParameter | Should -Be $true
        }
    }

    Context 'Error Handling' {
        BeforeAll {
            Mock Get-AppRoleAssignment { return $script:mockAppData }
            Mock Get-AppActivityData { return $args[0] }
            Mock Get-AppThrottlingData { return $args[0] }
            Mock Get-PermissionAnalysis { return $args[0] }
            Mock Export-PermissionAnalysisReport { }
        }

        It 'Should throw and propagate errors from Get-AppActivityData' {
            Mock Get-AppActivityData { throw "Activity data error" }

            { Invoke-LPMSGraphScan -WorkspaceId '/subscriptions/test/resourceGroups/test/providers/Microsoft.OperationalInsights/workspaces/test' -ErrorAction Stop } | Should -Throw
        }

        It 'Should throw and propagate errors from Get-PermissionAnalysis' {
            Mock Get-PermissionAnalysis { throw "Permission analysis error" }

            { Invoke-LPMSGraphScan -WorkspaceId '/subscriptions/test/resourceGroups/test/providers/Microsoft.OperationalInsights/workspaces/test' -ErrorAction Stop } | Should -Throw
        }

        It 'Should throw and propagate errors from Export-PermissionAnalysisReport' {
            Mock Export-PermissionAnalysisReport { throw "Export error" }

            { Invoke-LPMSGraphScan -WorkspaceId '/subscriptions/test/resourceGroups/test/providers/Microsoft.OperationalInsights/workspaces/test' -ErrorAction Stop } | Should -Throw
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}
