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
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "ConvertTo-TokenizeIds.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
        }
        else {
            throw "Could not find ConvertTo-TokenizeIds.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-TokenizeIds' {
    Context 'Parameter Validation' {
        It 'Should have mandatory Uri parameter' {
            $command = Get-Command -Name ConvertTo-TokenizeIds
            $command.Parameters['Uri'].Attributes.Mandatory | Should -Be $true
        }
    }

    Context 'Functionality' {
        It 'Should tokenize GUIDs in URI' {
            $uri = 'https://graph.microsoft.com/v1.0/users/12345678-1234-1234-1234-123456789012'
            $result = ConvertTo-TokenizeIds -Uri $uri
            $result | Should -Match '\{id\}'
        }

        It 'Should tokenize multiple GUIDs' {
            $uri = 'https://graph.microsoft.com/v1.0/users/12345678-1234-1234-1234-123456789012/messages/87654321-4321-4321-4321-210987654321'
            $result = ConvertTo-TokenizeIds -Uri $uri
            ($result | Select-String -Pattern '\{id\}' -AllMatches).Matches.Count | Should -BeGreaterThan 1
        }

        It 'Should preserve URI structure' {
            $uri = 'https://graph.microsoft.com/v1.0/users'
            $result = ConvertTo-TokenizeIds -Uri $uri
            $result | Should -BeLike 'https://graph.microsoft.com/v1.0/*'
        }

        It 'Should handle URIs without IDs' {
            $uri = 'https://graph.microsoft.com/v1.0/users'
            $result = ConvertTo-TokenizeIds -Uri $uri
            $result | Should -Be $uri
        }

        It 'Should handle beta endpoint' {
            $uri = 'https://graph.microsoft.com/beta/users/12345678-1234-1234-1234-123456789012'
            $result = ConvertTo-TokenizeIds -Uri $uri
            $result | Should -Match 'beta'
            $result | Should -Match '\{id\}'
        }
    }
}
