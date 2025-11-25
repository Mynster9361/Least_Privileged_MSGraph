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
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot\..\..\..\source\Private" -Filter "ConvertTo-TokenizeId.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
    }
    else {
        # Fallback for manual testing (dot source directly)
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot\..\..\..\source\Private" -Filter "ConvertTo-TokenizeId.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
        else {
            throw "Could not find ConvertTo-TokenizeId.ps1 and module is not built"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-TokenizeId' {
    Context 'Parameter Validation' {
        It 'Should have mandatory UriString parameter' {
            $command = Get-Command -Name ConvertTo-TokenizeId
            $command.Parameters['UriString'].Attributes.Mandatory | Should -Be $true
        }
    }

    Context 'Functionality' {
        It 'Should tokenize GUIDs in URI' {
            $uri = 'https://graph.microsoft.com/v1.0/users/12345678-1234-1234-1234-123456789012'
            $result = ConvertTo-TokenizeId -UriString $uri
            $result | Should -Match '\{id\}'
        }

        It 'Should tokenize multiple GUIDs' {
            $uri = 'https://graph.microsoft.com/v1.0/users/12345678-1234-1234-1234-123456789012/messages/87654321-4321-4321-4321-210987654321'
            $result = ConvertTo-TokenizeId -UriString $uri
            ($result | Select-String -Pattern '\{id\}' -AllMatches).Matches.Count | Should -BeGreaterThan 1
        }

        It 'Should preserve URI structure' {
            $uri = 'https://graph.microsoft.com/v1.0/users'
            $result = ConvertTo-TokenizeId -UriString $uri
            $result | Should -BeLike 'https://graph.microsoft.com/v1.0/*'
        }

        It 'Should handle URIs without IDs' {
            $uri = 'https://graph.microsoft.com/v1.0/users'
            $result = ConvertTo-TokenizeId -UriString $uri
            $result | Should -Be $uri
        }

        It 'Should handle beta endpoint' {
            $uri = 'https://graph.microsoft.com/beta/users/12345678-1234-1234-1234-123456789012'
            $result = ConvertTo-TokenizeId -UriString $uri
            $result | Should -Match 'beta'
            $result | Should -Match '\{id\}'
        }
    }
}
