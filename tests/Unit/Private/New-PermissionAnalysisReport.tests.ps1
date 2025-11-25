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
        $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "New-PermissionAnalysisReport.ps1" -ErrorAction SilentlyContinue

        if ($privateFunction) {
            . $privateFunction.FullName
            $script:moduleLoaded = $false
        }
        else {
            throw "Could not find New-PermissionAnalysisReport.ps1"
        }
    }
}

AfterAll {
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'New-PermissionAnalysisReport' {
    Context 'Parameter Validation' {
        It 'Should have mandatory AppData parameter' {
            $command = Get-Command -Name New-PermissionAnalysisReport
            $command.Parameters['AppData'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should not have mandatory OutputPath parameter' {
            $command = Get-Command -Name New-PermissionAnalysisReport
            $command.Parameters['OutputPath'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should not have mandatory ReportTitle parameter' {
            $command = Get-Command -Name New-PermissionAnalysisReport
            $command.Parameters['ReportTitle'].Attributes.Mandatory | Should -Be $false
        }

        It 'Should accept pipeline input for AppData' {
            $command = Get-Command -Name New-PermissionAnalysisReport
            $command.Parameters['AppData'].Attributes.ValueFromPipeline | Should -Be $true
        }

        It 'Should have CmdletBinding attribute' {
            $command = Get-Command -Name New-PermissionAnalysisReport
            $command.CmdletBinding | Should -Be $true
        }
    }

}
