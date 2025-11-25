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
        # Load all private functions first
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
    }

}
