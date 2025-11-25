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
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot\..\..\..\source\Private" -Filter "Convert-RelativeUriToAbsoluteUri.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
    }
    else {
        # Fallback for manual testing (dot source directly)
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot\..\..\..\source\Private" -Filter "Convert-RelativeUriToAbsoluteUri.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
        else {
            throw "Could not find Convert-RelativeUriToAbsoluteUri.ps1 and module is not built"
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
