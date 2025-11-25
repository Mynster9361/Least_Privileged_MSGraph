BeforeAll {
    $script:moduleName = 'LeastPrivilegedMSGraph'

    # Remove any existing module
    Get-Module $script:moduleName -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Create stub function for Invoke-EntraRequest to avoid type resolution issues
    if (-not (Get-Command -Name Invoke-EntraRequest -ErrorAction SilentlyContinue)) {
        function script:Invoke-EntraRequest {
            param(
                [string]$Service,
                [string]$Method,
                [string]$Path,
                [object]$Body
            )
        }
    }

    # Create stub functions for dependencies
    if (-not (Get-Command -Name Convert-RelativeUriToAbsoluteUri -ErrorAction SilentlyContinue)) {
        function script:Convert-RelativeUriToAbsoluteUri {
            param([string]$Uri)
        }
    }

    if (-not (Get-Command -Name ConvertTo-TokenizeIds -ErrorAction SilentlyContinue)) {
        function script:ConvertTo-TokenizeIds {
            param([string]$UriString)
        }
    }

    # Try to import the module
    $moduleInfo = Get-Module -Name $script:moduleName -ListAvailable | Select-Object -First 1

    if ($moduleInfo) {
        Import-Module -Name $script:moduleName -Force -ErrorAction Stop
        $script:moduleLoaded = $true
    }
    else {
        # Fallback: dot source the function directly for testing
        $convertRelative = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "Convert-RelativeUriToAbsoluteUri.ps1" -ErrorAction SilentlyContinue
        $convertTokenize = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "ConvertTo-TokenizeIds.ps1" -ErrorAction SilentlyContinue
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "Get-AppActivityFromLogs.ps1" -ErrorAction SilentlyContinue

        if ($convertRelative) {
            . $convertRelative.FullName
        }
        if ($convertTokenize) {
            . $convertTokenize.FullName
        }
        if ($privateFunction) {
            . $privateFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find Get-AppActivityFromLogs.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AppActivityFromLogs' {
    Context 'Parameter Validation' {
        It 'Should have mandatory logAnalyticsWorkspace parameter' {
            $command = Get-Command -Name Get-AppActivityFromLogs
            $command.Parameters['logAnalyticsWorkspace'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have mandatory spId parameter' {
            $command = Get-Command -Name Get-AppActivityFromLogs
            $command.Parameters['spId'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have mandatory days parameter' {
            $command = Get-Command -Name Get-AppActivityFromLogs
            $command.Parameters['days'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have optional retainRawUri parameter' {
            $command = Get-Command -Name Get-AppActivityFromLogs
            $command.Parameters['retainRawUri'].Attributes.Mandatory | Should -Be $false
            $command.Parameters['retainRawUri'].SwitchParameter | Should -Be $true
        }
    }
}
