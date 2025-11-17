function New-PermissionAnalysisReport {
    [CmdletBinding()]
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

        # Load the HTML template
        $moduleRoot = "."
        #TODO: fix for module use
        #$moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
        $templatePath = Join-Path -Path $moduleRoot -ChildPath "clean\Private\base.html"
        if (-not (Test-Path -Path $templatePath)) {
            throw "Template file not found: $templatePath"
        }

        $html = Get-Content -Path $templatePath -Raw
        $html = $html -replace '{% block app_data %}{% endblock %}', $jsonData
        $html = $html -replace '{% block title %}{% endblock %}', $ReportTitle
        $html = $html -replace '{% block generated_on %}{% endblock %}', (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        # Write the HTML to file
        $html | Out-File -FilePath $OutputPath -Encoding UTF8

        Write-Host "Report generated successfully: $OutputPath" -ForegroundColor Green
        Write-Host "Total applications in report: $($allAppData.Count)" -ForegroundColor Cyan
        
        return $OutputPath
    }
}