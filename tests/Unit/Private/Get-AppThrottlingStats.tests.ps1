BeforeAll {
    $script:moduleName = 'LeastPrivilegedMSGraph'

    # Remove any existing module
    Get-Module $script:moduleName -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Try to import the module
    $moduleInfo = Get-Module -Name $script:moduleName -ListAvailable | Select-Object -First 1

    if ($moduleInfo) {
        Import-Module -Name $script:moduleName -Force -ErrorAction Stop
    }
    else {
        # Fallback: dot source the function directly for testing
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "Get-AppThrottlingStats.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
        else {
            throw "Could not find Get-AppThrottlingStats.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AppThrottlingStats' {
    Context 'Parameter Validation' {
        It 'Should have mandatory WorkspaceId parameter' {
            $command = Get-Command -Name Get-AppThrottlingStats
            $command.Parameters['WorkspaceId'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have mandatory Days parameter' {
            $command = Get-Command -Name Get-AppThrottlingStats
            $command.Parameters['Days'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should have mandatory ServicePrincipalId parameter' {
            $command = Get-Command -Name Get-AppThrottlingStats
            $command.Parameters['ServicePrincipalId'].Attributes.Mandatory | Should -Be $false
        }
    }

}
