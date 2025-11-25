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

        # Dot-source the private functions to make them available in tests
        $privateFunctions = @(
            'Convert-RelativeUriToAbsoluteUri.ps1',
            'ConvertTo-TokenizeId.ps1',
            'Get-AppActivityFromLog.ps1'
        )

        foreach ($funcFile in $privateFunctions) {
            $funcPath = Get-ChildItem -Path "$PSScriptRoot\..\..\..\source\Private" -Filter $funcFile -ErrorAction SilentlyContinue
            if ($funcPath) {
                . $funcPath.FullName
            }
        }
    }
    else {
        # Fallback for manual testing (dot source directly)
        $privateFunctions = @(
            'Convert-RelativeUriToAbsoluteUri.ps1',
            'ConvertTo-TokenizeId.ps1',
            'Get-AppActivityFromLog.ps1'
        )

        foreach ($funcFile in $privateFunctions) {
            $funcPath = Get-ChildItem -Path "$PSScriptRoot\..\..\..\source\Private" -Filter $funcFile -ErrorAction SilentlyContinue
            if ($funcPath) {
                . $funcPath.FullName
            }
            else {
                throw "Could not find $funcFile and module is not built"
            }
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AppActivityFromLog' {
    Context 'Parameter Validation' {
        It 'Should have mandatory logAnalyticsWorkspace parameter' {
            $command = Get-Command -Name Get-AppActivityFromLog
            $command.Parameters['logAnalyticsWorkspace'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have mandatory spId parameter' {
            $command = Get-Command -Name Get-AppActivityFromLog
            $command.Parameters['spId'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have mandatory days parameter' {
            $command = Get-Command -Name Get-AppActivityFromLog
            $command.Parameters['days'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have optional retainRawUri parameter' {
            $command = Get-Command -Name Get-AppActivityFromLog
            $command.Parameters['retainRawUri'].Attributes.Mandatory | Should -Be $false
            $command.Parameters['retainRawUri'].SwitchParameter | Should -Be $true
        }
    }
}
