function Export-PermissionAnalysisReport {
    <#
.SYNOPSIS
    Generates an interactive HTML report for Microsoft Graph permission analysis.

.DESCRIPTION
    This function creates a comprehensive, interactive HTML report that visualizes permission analysis
    results for Microsoft Graph applications. The report includes statistics, filtering capabilities,
    and detailed views of each application's permissions, activities, and throttling information.

    The generated report features:
    - Dark/light mode toggle
    - Interactive data tables with sorting and filtering
    - Permission status indicators (optimal, excess, unmatched)
    - Throttling statistics and severity badges
    - Detailed modal views for each application
    - CSV export functionality
    - Responsive design with Tailwind CSS

    The function accepts application data via pipeline or parameter, processes it into JSON format,
    and embeds it into an HTML template with dynamic JavaScript for interactivity.

.PARAMETER AppData
    An array of application permission analysis objects. Each object should contain:
    - PrincipalName: The application name
    - PrincipalId: The application/service principal ID
    - CurrentPermissions: Array of currently assigned permissions
    - OptimalPermissions: Array of optimal permission objects with Permission and ActivitiesCovered
    - ExcessPermissions: Array of permissions that are not needed
    - RequiredPermissions: Array of permissions needed but not currently assigned
    - Activity: Array of API activity objects with Method and Uri properties
    - UnmatchedActivities: Array of activities that couldn't be matched
    - MatchedAllActivity: Boolean indicating if all activities were matched
    - AppRoleCount: Total number of app roles assigned
    - ThrottlingStats: Object containing throttling information (optional)

    This parameter accepts pipeline input.

.PARAMETER OutputPath
    The file path where the HTML report will be saved.
    Default: ".\PermissionAnalysisReport.html"

.PARAMETER ReportTitle
    The title displayed in the report header and browser tab.
    Default: "Microsoft Graph Permission Analysis Report"

.OUTPUTS
    String
    Returns the full path to the generated HTML report file.

.EXAMPLE
    $results | Export-PermissionAnalysisReport -OutputPath "C:\Reports\GraphPermissions.html"

    Generates a report from pipeline input and saves it to the specified location.

.EXAMPLE
    Export-PermissionAnalysisReport -AppData $analysisResults -ReportTitle "Production Apps - Q4 2024"

    Creates a report with a custom title using the default output path.

.EXAMPLE
    Get-MgServicePrincipal | Where-Object { $_.AppId -in $targetApps } |
        ForEach-Object { Analyze-AppPermissions $_ } |
        Export-PermissionAnalysisReport -OutputPath ".\Reports\$(Get-Date -Format 'yyyyMMdd')_Report.html"

    Pipelines multiple applications through analysis and generates a timestamped report.

.EXAMPLE
    $report = Export-PermissionAnalysisReport -AppData $data -OutputPath "report.html"
    Start-Process $report

    Generates the report and immediately opens it in the default browser.

.NOTES
    Template Requirements:
    - The function requires a base HTML template file located at "Private\base.html"
    - The template uses placeholder blocks: [app_data], [title], [generated_on]

    JSON Processing:
    - Application data is converted to JSON with depth 10 to preserve nested structures
    - Special characters are escaped for JavaScript embedding
    - Data is compressed to reduce file size

    Browser Compatibility:
    - Modern browsers (Chrome, Firefox, Edge, Safari) are recommended
    - JavaScript must be enabled for full functionality
    - Works offline once generated

    This function uses Write-Debug for processing information and for success messages.
#>
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [array]$AppData,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = ".\PermissionAnalysisReport.html",

        [Parameter(Mandatory = $false)]
        [string]$ReportTitle = "Microsoft Graph Permission Analysis Report"
    )

    begin {
        $allAppData = @()
    }

    process {
        # Accumulate all pipeline input
        $allAppData += $AppData
    }

    end {
        Write-Debug "Total apps received: $($allAppData.Count)"

        # Convert accumulated data to JSON for embedding
        $jsonData = $allAppData | ConvertTo-Json -Depth 10 -Compress

        # Properly escape for JavaScript - need to escape backslashes and quotes
        $jsonData = $jsonData.Replace('\', '\\').Replace('"', '\"').Replace([Environment]::NewLine, '\n')

        # Get the module root directory (handles versioned paths correctly)
        $moduleRoot = $MyInvocation.MyCommand.Module.ModuleBase

        # Load the HTML template
        $templatePath = Join-Path -Path $moduleRoot -ChildPath "data\base.html"

        Write-Debug "Module root: $moduleRoot"
        Write-Debug "Template path: $templatePath"

        if (-not (Test-Path -Path $templatePath)) {
            throw "Template file not found: $templatePath"
        }

        $html = Get-Content -Path $templatePath -Raw
        $html = $html -replace '{% block app_data %}{% endblock %}', $jsonData
        $html = $html -replace '{% block title %}{% endblock %}', $ReportTitle
        $html = $html -replace '{% block generated_on %}{% endblock %}', (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        # Write the HTML to file
        $html | Out-File -FilePath $OutputPath -Encoding UTF8

        "Report generated successfully: $OutputPath"
        "Total applications in report: $($allAppData.Count)"

        return $OutputPath
    }
}
