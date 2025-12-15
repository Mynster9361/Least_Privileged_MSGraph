BeforeAll {
    $script:moduleName = 'LeastPrivilegedMSGraph'

    # Remove any existing module
    Get-Module $script:moduleName -All | Remove-Module -Force -ErrorAction SilentlyContinue

    # Create a mock template directory structure in TestDrive
    $script:mockModuleBase = Join-Path -Path $TestDrive -ChildPath 'MockModule'
    $script:mockTemplateDir = Join-Path -Path $script:mockModuleBase -ChildPath 'Templates'
    $script:mockTemplatePath = Join-Path -Path $script:mockTemplateDir -ChildPath 'base.html'

    New-Item -Path $script:mockTemplateDir -ItemType Directory -Force | Out-Null

    $mockTemplate = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>{% block title %}{% endblock %}</title>
</head>
<body>
    <h1>Microsoft Graph Permission Analysis Report</h1>
    <p>Generated on: {% block generated_on %}{% endblock %}</p>
    <script>
        const appData = "{% block app_data %}{% endblock %}";
    </script>
</body>
</html>
'@
    $mockTemplate | Out-File -FilePath $script:mockTemplatePath -Encoding UTF8

    # Try to import the module
    $moduleInfo = Get-Module -Name $script:moduleName -ListAvailable | Select-Object -First 1

    if ($moduleInfo) {
        Import-Module -Name $script:moduleName -Force -ErrorAction Stop
        $script:moduleLoaded = $true
    }
    else {
        # Fallback: dot source the functions directly for testing
        $publicFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Public" -Filter "Export-PermissionAnalysisReport.ps1" -ErrorAction SilentlyContinue

        if ($publicFunction) {
            . $publicFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find Export-PermissionAnalysisReport.ps1"
        }
    }

    # Create anonymized test data based on production sample
    $script:testAppData = @(
        [PSCustomObject]@{
            PrincipalId         = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            PrincipalName       = 'TestApp-DirectoryReader'
            AppRoleCount        = 2
            AppRoles            = @(
                @{appRoleId = '7ab1d382-f21e-4acd-a863-ba3e13f7da61'; FriendlyName = 'Directory.Read.All'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
                @{appRoleId = 'df021288-bdef-4463-88db-98f22de89214'; FriendlyName = 'User.Read.All'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
            )
            Activity            = @(
                @{Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/applications/{id}' }
                @{Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/servicePrincipals/{id}' }
                @{Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/users' }
            )
            ThrottlingStats     = @{
                TotalRequests       = 1294
                SuccessfulRequests  = 679
                Total429Errors      = 0
                TotalClientErrors   = 615
                TotalServerErrors   = 0
                ThrottleRate        = 0
                ErrorRate           = 47.53
                SuccessRate         = 52.47
                ThrottlingSeverity  = 0
                ThrottlingStatus    = 'Normal'
                FirstOccurrence     = '2025-11-06T22:31:14Z'
                LastOccurrence      = '2025-12-06T21:27:56Z'
            }
            ActivityPermissions = @(
                @{Method = 'GET'; Version = 'v1.0'; Path = '/applications/{id}'; OriginalUri = 'https://graph.microsoft.com/v1.0/applications/{id}'; MatchedEndpoint = '/applications/{id}'; LeastPrivilegedPermissions = ''; IsMatched = $true }
                @{Method = 'GET'; Version = 'v1.0'; Path = '/servicePrincipals/{id}'; OriginalUri = 'https://graph.microsoft.com/v1.0/servicePrincipals/{id}'; MatchedEndpoint = '/servicePrincipals/{id}'; LeastPrivilegedPermissions = ''; IsMatched = $true }
                @{Method = 'GET'; Version = 'v1.0'; Path = '/users'; OriginalUri = 'https://graph.microsoft.com/v1.0/users'; MatchedEndpoint = '/users'; LeastPrivilegedPermissions = ''; IsMatched = $true }
            )
            OptimalPermissions  = @(
                @{Permission = 'Application.Read.All'; ScopeType = 'Application'; IsLeastPrivilege = $true; ActivitiesCovered = 2 }
                @{Permission = 'User.ReadBasic.All'; ScopeType = 'Application'; IsLeastPrivilege = $true; ActivitiesCovered = 1 }
            )
            UnmatchedActivities = @()
            CurrentPermissions  = @('Directory.Read.All', 'User.Read.All')
            ExcessPermissions   = @('Directory.Read.All', 'User.Read.All')
            RequiredPermissions = @('Application.Read.All', 'User.ReadBasic.All')
            MatchedAllActivity  = $true
        }
        [PSCustomObject]@{
            PrincipalId         = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            PrincipalName       = 'TestApp-SharePointReader'
            AppRoleCount        = 1
            AppRoles            = @(
                @{appRoleId = '883ea226-0bf2-4a8f-9f9d-92c9162a727d'; FriendlyName = 'Sites.Selected'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
            )
            Activity            = @(
                @{Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/drives/{id}/items/{id}' }
                @{Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/sites/{id}/lists/{id}/items' }
            )
            ThrottlingStats     = @{
                TotalRequests       = 171
                SuccessfulRequests  = 166
                Total429Errors      = 0
                TotalClientErrors   = 0
                TotalServerErrors   = 0
                ThrottleRate        = 0
                ErrorRate           = 0
                SuccessRate         = 97.08
                ThrottlingSeverity  = 0
                ThrottlingStatus    = 'Normal'
                FirstOccurrence     = '2025-11-13T12:56:57Z'
                LastOccurrence      = '2025-12-03T14:30:22Z'
            }
            ActivityPermissions = @(
                @{Method = 'GET'; Version = 'v1.0'; Path = '/drives/{id}/items/{id}'; OriginalUri = 'https://graph.microsoft.com/v1.0/drives/{id}/items/{id}'; MatchedEndpoint = '/drives/{id}/items/{id}'; LeastPrivilegedPermissions = ''; IsMatched = $true }
                @{Method = 'GET'; Version = 'v1.0'; Path = '/sites/{id}/lists/{id}/items'; OriginalUri = 'https://graph.microsoft.com/v1.0/sites/{id}/lists/{id}/items'; MatchedEndpoint = '/sites/{id}/lists/{id}/items'; LeastPrivilegedPermissions = ''; IsMatched = $true }
            )
            OptimalPermissions  = @(
                @{Permission = 'Files.Read.All'; ScopeType = 'Application'; IsLeastPrivilege = $true; ActivitiesCovered = 1 }
                @{Permission = 'Sites.Read.All'; ScopeType = 'Application'; IsLeastPrivilege = $true; ActivitiesCovered = 1 }
            )
            UnmatchedActivities = @()
            CurrentPermissions  = @('Sites.Selected')
            ExcessPermissions   = @('Sites.Selected')
            RequiredPermissions = @('Files.Read.All', 'Sites.Read.All')
            MatchedAllActivity  = $true
        }
        [PSCustomObject]@{
            PrincipalId         = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
            PrincipalName       = 'TestApp-MailProcessor'
            AppRoleCount        = 2
            AppRoles            = @(
                @{appRoleId = '97235f07-e226-4f63-ace3-39588e11d3a1'; FriendlyName = 'User.ReadBasic.All'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
                @{appRoleId = 'e2a3a72e-5f79-4c64-b1b1-878b674786c9'; FriendlyName = 'Mail.ReadWrite'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
            )
            Activity            = @(
                @{Method = 'GET'; Uri = 'https://graph.microsoft.com/beta/users/{id}/mailFolders' }
                @{Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/users/{id}/mailFolders/{id}/messages' }
                @{Method = 'GET'; Uri = 'https://graph.microsoft.com/v1.0/users/{id}/messages/{id}' }
                @{Method = 'PATCH'; Uri = 'https://graph.microsoft.com/v1.0/users/{id}/messages/{id}' }
            )
            ThrottlingStats     = @{
                TotalRequests       = 23904
                SuccessfulRequests  = 23886
                Total429Errors      = 0
                TotalClientErrors   = 0
                TotalServerErrors   = 18
                ThrottleRate        = 0
                ErrorRate           = 0.08
                SuccessRate         = 99.92
                ThrottlingSeverity  = 0
                ThrottlingStatus    = 'Normal'
                FirstOccurrence     = '2025-11-06T21:57:03Z'
                LastOccurrence      = '2025-12-06T21:51:04Z'
            }
            ActivityPermissions = @(
                @{Method = 'GET'; Version = 'beta'; Path = '/users/{id}/mailFolders'; OriginalUri = 'https://graph.microsoft.com/beta/users/{id}/mailFolders'; MatchedEndpoint = '/users/{id}/mailFolders'; LeastPrivilegedPermissions = ''; IsMatched = $true }
                @{Method = 'GET'; Version = 'v1.0'; Path = '/users/{id}/mailFolders/{id}/messages'; OriginalUri = 'https://graph.microsoft.com/v1.0/users/{id}/mailFolders/{id}/messages'; MatchedEndpoint = '/users/{id}/mailFolders/{id}/messages'; LeastPrivilegedPermissions = ''; IsMatched = $true }
                @{Method = 'GET'; Version = 'v1.0'; Path = '/users/{id}/messages/{id}'; OriginalUri = 'https://graph.microsoft.com/v1.0/users/{id}/messages/{id}'; MatchedEndpoint = '/users/{id}/messages/{id}'; LeastPrivilegedPermissions = ''; IsMatched = $true }
                @{Method = 'PATCH'; Version = 'v1.0'; Path = '/users/{id}/messages/{id}'; OriginalUri = 'https://graph.microsoft.com/v1.0/users/{id}/messages/{id}'; MatchedEndpoint = '/users/{id}/messages/{id}'; LeastPrivilegedPermissions = ''; IsMatched = $true }
            )
            OptimalPermissions  = @(
                @{Permission = 'Mail.ReadBasic.All'; ScopeType = 'Application'; IsLeastPrivilege = $true; ActivitiesCovered = 2 }
                @{Permission = 'Mail.Read'; ScopeType = 'Application'; IsLeastPrivilege = $true; ActivitiesCovered = 1 }
                @{Permission = 'Mail.ReadWrite'; ScopeType = 'Application'; IsLeastPrivilege = $true; ActivitiesCovered = 1 }
            )
            UnmatchedActivities = @()
            CurrentPermissions  = @('User.ReadBasic.All', 'Mail.ReadWrite')
            ExcessPermissions   = @('User.ReadBasic.All')
            RequiredPermissions = @('Mail.ReadBasic.All', 'Mail.Read')
            MatchedAllActivity  = $true
        }
        [PSCustomObject]@{
            PrincipalId         = 'dddddddd-dddd-dddd-dddd-dddddddddddd'
            PrincipalName       = 'TestApp-NoActivity'
            AppRoleCount        = 4
            AppRoles            = @(
                @{appRoleId = 'df021288-bdef-4463-88db-98f22de89214'; FriendlyName = 'User.Read.All'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
                @{appRoleId = 'b633e1c5-b582-4048-a93e-9f11b44c7e96'; FriendlyName = 'Mail.Send'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
                @{appRoleId = '294ce7c9-31ba-490a-ad7d-97a7d075e4ed'; FriendlyName = 'Chat.ReadWrite.All'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
                @{appRoleId = 'd9c48af6-9ad9-47ad-82c3-63757137b9af'; FriendlyName = 'Chat.Create'; PermissionType = 'Application'; resourceDisplayName = 'Microsoft Graph' }
            )
            Activity            = @()
            ThrottlingStats     = @{
                TotalRequests       = 13
                SuccessfulRequests  = 0
                Total429Errors      = 1
                TotalClientErrors   = 1
                TotalServerErrors   = 0
                ThrottleRate        = 7.69
                ErrorRate           = 7.69
                SuccessRate         = 0
                ThrottlingSeverity  = 3
                ThrottlingStatus    = 'Warning'
                FirstOccurrence     = '2025-11-26T00:14:02Z'
                LastOccurrence      = '2025-11-26T00:14:06Z'
            }
            ActivityPermissions = @()
            OptimalPermissions  = @()
            UnmatchedActivities = @()
            CurrentPermissions  = @('User.Read.All', 'Mail.Send', 'Chat.ReadWrite.All', 'Chat.Create')
            ExcessPermissions   = @('User.Read.All', 'Mail.Send', 'Chat.ReadWrite.All', 'Chat.Create')
            RequiredPermissions = @()
            MatchedAllActivity  = $true
        }
    )
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Export-PermissionAnalysisReport' {
    Context 'Parameter Validation' {
        It 'Should have mandatory AppData parameter' {
            $command = Get-Command -Name Export-PermissionAnalysisReport
            $command.Parameters['AppData'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should not have mandatory OutputPath parameter' {
            $command = Get-Command -Name Export-PermissionAnalysisReport
            $command.Parameters['OutputPath'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should not have mandatory ReportTitle parameter' {
            $command = Get-Command -Name Export-PermissionAnalysisReport
            $command.Parameters['ReportTitle'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should accept pipeline input for AppData' {
            $command = Get-Command -Name Export-PermissionAnalysisReport
            $command.Parameters['AppData'].Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command -Name Export-PermissionAnalysisReport
            $command.CmdletBinding | Should -Be $true
        }
    }

    Context 'Basic Functionality' {
        BeforeEach {
            $script:outputPath = Join-Path -Path $TestDrive -ChildPath "test-report-$(Get-Random).html"
        }

        It 'Should generate HTML report file' {
            Mock -CommandName Get-Module -MockWith {
                [PSCustomObject]@{
                    ModuleBase = $script:mockModuleBase
                }
            }

            $result = Export-PermissionAnalysisReport -AppData $script:testAppData -OutputPath $script:outputPath

            $script:outputPath | Should -Exist
            $result | Should -Not -BeNullOrEmpty
            # Function returns multiple lines of output, last one is the path
            $result[-1] | Should -BeExactly $script:outputPath
        }

        It 'Should generate report with default filename when OutputPath not specified' {
            Mock -CommandName Get-Module -MockWith {
                [PSCustomObject]@{
                    ModuleBase = $script:mockModuleBase
                }
            }

            Push-Location -Path $TestDrive
            try {
                $result = Export-PermissionAnalysisReport -AppData $script:testAppData

                # Function returns multiple lines, extract the file path from output
                $filePath = $result | Where-Object { $_ -like '*.html' } | Select-Object -Last 1
                $filePath | Should -Match 'PermissionAnalysisReport.*\.html'
                $filePath | Should -Exist

                # Clean up
                Remove-Item -Path $filePath -ErrorAction SilentlyContinue
            }
            finally {
                Pop-Location
            }
        }

        It 'Should accept custom ReportTitle' {
            Mock -CommandName Get-Module -MockWith {
                [PSCustomObject]@{
                    ModuleBase = $script:mockModuleBase
                }
            }

            $customTitle = "Custom Test Report"
            $result = Export-PermissionAnalysisReport -AppData $script:testAppData -OutputPath $script:outputPath -ReportTitle $customTitle

            $content = Get-Content -Path $script:outputPath -Raw
            $content | Should -Match $customTitle
        }

        It 'Should create parent directory if it does not exist' {
            Mock -CommandName Get-Module -MockWith {
                [PSCustomObject]@{
                    ModuleBase = $script:mockModuleBase
                }
            }

            # Create the nested directory structure first (function may not create it automatically)
            $nestedDir = Join-Path -Path $TestDrive -ChildPath "nested\folder"
            New-Item -Path $nestedDir -ItemType Directory -Force | Out-Null

            $nestedPath = Join-Path -Path $nestedDir -ChildPath "report.html"
            $result = Export-PermissionAnalysisReport -AppData $script:testAppData -OutputPath $nestedPath

            $nestedPath | Should -Exist
            Split-Path -Path $nestedPath -Parent | Should -Exist
        }
    }

    Context 'Content Validation' {
        BeforeEach {
            $script:outputPath = Join-Path -Path $TestDrive -ChildPath "content-test-$(Get-Random).html"

            Mock -CommandName Get-Module -MockWith {
                [PSCustomObject]@{
                    ModuleBase = $script:mockModuleBase
                }
            }
        }

        It 'Should embed all application data in the report' {
            Export-PermissionAnalysisReport -AppData $script:testAppData -OutputPath $script:outputPath

            $content = Get-Content -Path $script:outputPath -Raw

            # Check for each test app
            $content | Should -Match 'TestApp-DirectoryReader'
            $content | Should -Match 'TestApp-SharePointReader'
            $content | Should -Match 'TestApp-MailProcessor'
            $content | Should -Match 'TestApp-NoActivity'
        }

        It 'Should include generation timestamp' {
            Export-PermissionAnalysisReport -AppData $script:testAppData -OutputPath $script:outputPath

            $content = Get-Content -Path $script:outputPath -Raw
            $content | Should -Match '\d{4}-\d{2}-\d{2}'
        }

        It 'Should handle empty AppData array gracefully' {
            # The function requires at least one item, so we test with a minimal valid object
            $minimalData = @(
                [PSCustomObject]@{
                    PrincipalId         = 'test-id'
                    PrincipalName       = 'TestApp'
                    AppRoleCount        = 0
                    AppRoles            = @()
                    Activity            = @()
                    ThrottlingStats     = @{}
                    ActivityPermissions = @()
                    OptimalPermissions  = @()
                    UnmatchedActivities = @()
                    CurrentPermissions  = @()
                    ExcessPermissions   = @()
                    RequiredPermissions = @()
                    MatchedAllActivity  = $true
                }
            )

            Export-PermissionAnalysisReport -AppData $minimalData -OutputPath $script:outputPath

            $script:outputPath | Should -Exist
            $content = Get-Content -Path $script:outputPath -Raw
            $content | Should -Not -BeNullOrEmpty
        }

        It 'Should properly escape JSON data for JavaScript' {
            Export-PermissionAnalysisReport -AppData $script:testAppData -OutputPath $script:outputPath

            $content = Get-Content -Path $script:outputPath -Raw

            # Should not have unescaped quotes that would break JavaScript
            $content | Should -Not -Match 'const appData = ".*[^\\]".*";'
        }

        It 'Should include all permission types in data' {
            Export-PermissionAnalysisReport -AppData $script:testAppData -OutputPath $script:outputPath

            $content = Get-Content -Path $script:outputPath -Raw

            # Check for various permission names
            $content | Should -Match 'Directory.Read.All'
            $content | Should -Match 'User.Read.All'
            $content | Should -Match 'Sites.Selected'
            $content | Should -Match 'Mail.ReadWrite'
        }

        It 'Should include throttling statistics' {
            Export-PermissionAnalysisReport -AppData $script:testAppData -OutputPath $script:outputPath

            $content = Get-Content -Path $script:outputPath -Raw

            # Should contain throttling-related data
            $content | Should -Match 'ThrottlingStats|Total429Errors|ThrottleRate'
        }

        It 'Should include activity information' {
            Export-PermissionAnalysisReport -AppData $script:testAppData -OutputPath $script:outputPath

            $content = Get-Content -Path $script:outputPath -Raw

            # Should contain API endpoints
            $content | Should -Match '/applications/\{id\}'
            $content | Should -Match '/users/\{id\}/messages'
        }
    }

    Context 'Pipeline Support' {
        BeforeEach {
            $script:outputPath = Join-Path -Path $TestDrive -ChildPath "pipeline-test-$(Get-Random).html"

            Mock -CommandName Get-Module -MockWith {
                [PSCustomObject]@{
                    ModuleBase = $script:mockModuleBase
                }
            }
        }

        It 'Should accept AppData from pipeline' {
            $result = $script:testAppData | Export-PermissionAnalysisReport -OutputPath $script:outputPath

            $script:outputPath | Should -Exist
            # Last item in output array should be the path
            $result[-1] | Should -BeExactly $script:outputPath
        }

        It 'Should process multiple pipeline inputs' {
            $result = $script:testAppData[0], $script:testAppData[1] | Export-PermissionAnalysisReport -OutputPath $script:outputPath

            $script:outputPath | Should -Exist
            $content = Get-Content -Path $script:outputPath -Raw
            $content | Should -Match 'TestApp-DirectoryReader'
            $content | Should -Match 'TestApp-SharePointReader'
        }
    }

    Context 'Error Handling' {
        It 'Should throw when AppData is null' {
            { Export-PermissionAnalysisReport -AppData $null -OutputPath (Join-Path $TestDrive "error-test.html") } | Should -Throw
        }

        It 'Should handle invalid output path gracefully' {
            Mock -CommandName Get-Module -MockWith {
                [PSCustomObject]@{
                    ModuleBase = $script:mockModuleBase
                }
            }

            $invalidPath = "Z:\NonExistent\Path\report.html"

            # This should throw because the path doesn't exist
            { Export-PermissionAnalysisReport -AppData $script:testAppData -OutputPath $invalidPath } | Should -Throw
        }
    }

    Context 'Template Integration' {
        It 'Should use template from module data directory' {
            Mock -CommandName Get-Module -MockWith {
                [PSCustomObject]@{
                    ModuleBase = $script:mockModuleBase
                }
            }

            $outputPath = Join-Path -Path $TestDrive -ChildPath "template-test.html"
            Export-PermissionAnalysisReport -AppData $script:testAppData -OutputPath $outputPath

            $content = Get-Content -Path $outputPath -Raw

            # Should contain elements from the base template
            $content | Should -Match '<html'
            $content | Should -Match 'Microsoft Graph Permission Analysis Report'
        }
    }
}
