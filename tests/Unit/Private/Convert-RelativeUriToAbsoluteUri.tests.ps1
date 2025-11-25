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
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "Convert-RelativeUriToAbsoluteUri.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
        else {
            throw "Could not find Convert-RelativeUriToAbsoluteUri.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Convert-RelativeUriToAbsoluteUri' {
    Context 'Parameter Validation' {
        It 'Should have mandatory Uri parameter' {
            $command = Get-Command -Name Convert-RelativeUriToAbsoluteUri
            $command.Parameters['Uri'].Attributes.Mandatory | Should -Be $true
        }
    }

    Context 'Functionality' {
        It 'Should handle already absolute URIs' {
            $uri = 'https://graph.microsoft.com/v1.0/users'
            $result = Convert-RelativeUriToAbsoluteUri -Uri $uri
            $result.Uri | Should -Be $uri
        }

        It 'Should preserve query parameters' {
            $result = Convert-RelativeUriToAbsoluteUri -Uri 'https://graph.microsoft.com/v1.0/users?$filter=startswith(displayName,''test'')'
            $result.Uri | Should -BeLike 'https://graph.microsoft.com/v1.0/users?*'
        }

        It 'Should handle beta endpoint with query' {
            $result = Convert-RelativeUriToAbsoluteUri -Uri 'https://graph.microsoft.com/beta/groups?$top=10'
            $result.Uri | Should -BeLike 'https://graph.microsoft.com/beta/groups?*'
        }
    }
}
