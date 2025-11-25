<#
.SYNOPSIS
    Prepares documentation for GitHub Pages deployment.

.DESCRIPTION
    Consolidates documentation from build output and repository root into a single directory
    for deployment to GitHub Pages. Creates an index.html if one doesn't exist.

.PARAMETER BuildOutputPath
    Path to the build output directory containing generated documentation.

.PARAMETER RepositoryDocsPath
    Path to the repository's docs directory.

.PARAMETER OutputPath
    Path where the consolidated documentation should be created.

.EXAMPLE
    .\build\Prepare-Documentation.ps1 -BuildOutputPath "./output" -OutputPath "./gh-pages-docs"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BuildOutputPath = "./output",

    [Parameter(Mandatory = $false)]
    [string]$RepositoryDocsPath = "./docs",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./gh-pages-docs"
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Preparing Documentation for GitHub Pages ===" -ForegroundColor Cyan

# Create the output directory
Write-Host "Creating output directory: $OutputPath" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

# Copy generated docs from build output if they exist
$buildDocsPath = Join-Path $BuildOutputPath "docs"
if (Test-Path $buildDocsPath) {
    Write-Host "Copying documentation from build output: $buildDocsPath" -ForegroundColor Green
    Copy-Item -Path "$buildDocsPath/*" -Destination $OutputPath -Recurse -Force
    Get-ChildItem $buildDocsPath | ForEach-Object {
        Write-Host "  ✓ Copied: $($_.Name)" -ForegroundColor Gray
    }
}
else {
    Write-Warning "Build documentation not found at: $buildDocsPath"
}

# Copy any docs from repository root if they exist
if (Test-Path $RepositoryDocsPath) {
    Write-Host "Copying documentation from repository: $RepositoryDocsPath" -ForegroundColor Green
    Copy-Item -Path "$RepositoryDocsPath/*" -Destination $OutputPath -Recurse -Force
    Get-ChildItem $RepositoryDocsPath | ForEach-Object {
        Write-Host "  ✓ Copied: $($_.Name)" -ForegroundColor Gray
    }
}
else {
    Write-Warning "Repository documentation not found at: $RepositoryDocsPath"
}

# Copy README.md if it exists
$readmePath = "./README.md"
if (Test-Path $readmePath) {
    Write-Host "Copying README.md" -ForegroundColor Green
    Copy-Item -Path $readmePath -Destination $OutputPath -Force
}

# Create an index.html if it doesn't exist
$indexPath = Join-Path $OutputPath "index.html"
if (-not (Test-Path $indexPath)) {
    Write-Host "Creating index.html" -ForegroundColor Green

    # Get list of markdown files for the index
    $markdownFiles = Get-ChildItem -Path $OutputPath -Filter "*.md" -File | Sort-Object Name

    $fileLinks = $markdownFiles | ForEach-Object {
        "        <li><a href=`"$($_.Name)`">$($_.BaseName)</a></li>"
    }

    $fileLinksHtml = if ($fileLinks) {
        $fileLinks -join "`n"
    }
    else {
        "        <li>No documentation files found</li>"
    }

    $indexHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LeastPrivilegedMSGraph Documentation</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            max-width: 900px;
            margin: 0 auto;
            padding: 20px;
            color: #333;
        }
        h1 {
            color: #0066cc;
            border-bottom: 2px solid #0066cc;
            padding-bottom: 10px;
        }
        ul {
            list-style-type: none;
            padding: 0;
        }
        li {
            margin: 10px 0;
        }
        a {
            color: #0066cc;
            text-decoration: none;
            padding: 5px 10px;
            border-left: 3px solid #0066cc;
            display: inline-block;
        }
        a:hover {
            background-color: #f0f0f0;
        }
    </style>
</head>
<body>
    <h1>LeastPrivilegedMSGraph Documentation</h1>
    <p>PowerShell module for analyzing and determining least privileged permissions for Microsoft Graph applications.</p>

    <h2>Available Documentation</h2>
    <ul>
$fileLinksHtml
    </ul>

    <h2>Quick Links</h2>
    <ul>
        <li><a href="https://github.com/Mynster9361/Least_Privileged_MSGraph">GitHub Repository</a></li>
        <li><a href="https://www.powershellgallery.com/packages/LeastPrivilegedMSGraph">PowerShell Gallery</a></li>
    </ul>
</body>
</html>
"@

    $indexHtml | Out-File -FilePath $indexPath -Encoding UTF8
    Write-Host "  ✓ Created index.html with $($markdownFiles.Count) documentation files" -ForegroundColor Gray
}
else {
    Write-Host "index.html already exists, skipping creation" -ForegroundColor Yellow
}

# Display summary
Write-Host "`n=== Documentation Preparation Complete ===" -ForegroundColor Cyan
Write-Host "Output directory: $OutputPath" -ForegroundColor Green
Write-Host "`nContents:" -ForegroundColor Yellow
Get-ChildItem $OutputPath -Recurse | ForEach-Object {
    $relativePath = $_.FullName.Replace("$(Resolve-Path $OutputPath)\", "")
    Write-Host "  - $relativePath" -ForegroundColor Gray
}

Write-Host "`n✓ Documentation ready for deployment" -ForegroundColor Green
