<#
.SYNOPSIS
    Prepares documentation for GitHub Pages deployment with Docsy Jekyll theme.
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

Write-Host "=== Preparing Documentation for GitHub Pages (Docsy Jekyll) ===" -ForegroundColor Cyan

# Create the output directory structure
Write-Host "Creating output directory structure" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
New-Item -ItemType Directory -Path "$OutputPath/commands" -Force | Out-Null
New-Item -ItemType Directory -Path "$OutputPath/_data" -Force | Out-Null
New-Item -ItemType Directory -Path "$OutputPath/pages" -Force | Out-Null

# Copy Jekyll configuration
Write-Host "Copying Jekyll configuration files" -ForegroundColor Green
$configFiles = @('_config.yml')
foreach ($file in $configFiles) {
    $sourcePath = "./.ghpages/$file"
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $OutputPath -Force
        Write-Host "  ✓ Copied: $file" -ForegroundColor Gray
    }
    else {
        Write-Warning "Configuration file not found: $sourcePath"
    }
}

# Copy _data folder (navigation and toc)
Write-Host "Copying navigation configuration" -ForegroundColor Green
if (Test-Path "./.ghpages/_data") {
    Copy-Item -Path "./.ghpages/_data/*" -Destination "$OutputPath/_data/" -Force -Recurse
    Write-Host "  ✓ Copied _data folder" -ForegroundColor Gray
    Get-ChildItem "$OutputPath/_data" | ForEach-Object {
        Write-Host "    - $($_.Name)" -ForegroundColor DarkGray
    }
}
else {
    Write-Warning "_data folder not found at ./.ghpages/_data"
}

# Copy main pages
Write-Host "Copying main documentation pages" -ForegroundColor Green
$pageFiles = @('index.md', 'getting-started.md', 'commands.md', 'examples.md')
foreach ($file in $pageFiles) {
    $sourcePath = "./.ghpages/$file"
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination "$OutputPath/pages/" -Force
        Write-Host "  ✓ Copied: $file to pages/" -ForegroundColor Gray
    }
    else {
        Write-Warning "Page file not found: $sourcePath"
    }
}

# Also copy index.md to root for home page
if (Test-Path "./.ghpages/index.md") {
    Copy-Item -Path "./.ghpages/index.md" -Destination $OutputPath -Force
    Write-Host "  ✓ Copied: index.md to root" -ForegroundColor Gray
}

# Copy generated command docs from build output
$buildDocsPath = Join-Path $BuildOutputPath "docs"
if (Test-Path $buildDocsPath) {
    Write-Host "Processing command documentation from build output" -ForegroundColor Green

    Get-ChildItem $buildDocsPath -Filter "*.md" -File | ForEach-Object {
        $fileName = $_.Name
        $baseName = $_.BaseName
        $destPath = Join-Path "$OutputPath/pages/commands" $fileName

        # Ensure commands directory exists
        New-Item -ItemType Directory -Path "$OutputPath/pages/commands" -Force | Out-Null

        # Read the content
        $content = Get-Content -Path $_.FullName -Raw

        # Extract synopsis
        $synopsis = ""
        if ($content -match '##\s+SYNOPSIS\s+(.+?)(?=##|\z)') {
            $synopsis = $matches[1].Trim() -replace '\r?\n', ' '
        }

        # Create front matter
        $frontMatter = @"
---
title: $baseName
tags:
 - powershell
 - cmdlet
description: $synopsis
permalink: /commands/$baseName
---

"@

        # Combine and save
        $fullContent = $frontMatter + $content
        Set-Content -Path $destPath -Value $fullContent -NoNewline

        Write-Host "  ✓ Processed: $fileName" -ForegroundColor Gray
    }
}
else {
    Write-Warning "Build documentation not found at: $buildDocsPath"
}

# Display detailed summary
Write-Host "`n=== Documentation Preparation Complete ===" -ForegroundColor Cyan
Write-Host "Output directory: $OutputPath" -ForegroundColor Green
Write-Host "`nDirectory Structure:" -ForegroundColor Yellow

$tree = Get-ChildItem $OutputPath -Recurse | Where-Object { $_.PSIsContainer -or $_.Extension -eq '.md' -or $_.Extension -eq '.yml' }
$tree | ForEach-Object {
    $depth = ($_.FullName.Replace($OutputPath, "").Split([IO.Path]::DirectorySeparatorChar).Count - 2)
    $indent = "  " * $depth
    $name = if ($_.PSIsContainer) {
        "$($_.Name)/" 
    }
    else {
        $_.Name 
    }
    Write-Host "$indent├── $name" -ForegroundColor Gray
}

Write-Host "`n✓ Documentation ready for Jekyll (Docsy) deployment" -ForegroundColor Green
