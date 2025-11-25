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
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot\..\..\..\source\Private" -Filter "Get-AppThrottlingStat.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
    }
    else {
        # Fallback for manual testing (dot source directly)
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot\..\..\..\source\Private" -Filter "Get-AppThrottlingStat.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
        else {
            throw "Could not find Get-AppThrottlingStat.ps1 and module is not built"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AppThrottlingStat' {
    Context 'Parameter Validation' {
        It 'Should have mandatory WorkspaceId parameter' {
            $command = Get-Command -Name Get-AppThrottlingStat
            $command.Parameters['WorkspaceId'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have mandatory Days parameter' {
            $command = Get-Command -Name Get-AppThrottlingStat
            $command.Parameters['Days'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should have mandatory ServicePrincipalId parameter' {
            $command = Get-Command -Name Get-AppThrottlingStat
            $command.Parameters['ServicePrincipalId'].Attributes.Mandatory | Should -Be $false
        }
    }

}
