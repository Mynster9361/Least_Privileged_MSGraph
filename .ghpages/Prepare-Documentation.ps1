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
New-Item -ItemType Directory -Path "$OutputPath/_commands" -Force | Out-Null

# Copy Jekyll configuration files
Write-Host "Copying Jekyll configuration files" -ForegroundColor Green
$configFiles = @('_config.yml', 'index.md', 'getting-started.md', 'commands.md', 'examples.md')
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

# Copy generated command docs from build output
$buildDocsPath = Join-Path $BuildOutputPath "docs"
if (Test-Path $buildDocsPath) {
    Write-Host "Processing command documentation from build output" -ForegroundColor Green

    Get-ChildItem $buildDocsPath -Filter "*.md" -File | ForEach-Object {
        $fileName = $_.Name
        $baseName = $_.BaseName
        $destPath = Join-Path "$OutputPath/_commands" $fileName

        # Read the content
        $content = Get-Content -Path $_.FullName -Raw

        # Extract synopsis from markdown if available
        $synopsis = ""
        if ($content -match '##\s+SYNOPSIS\s+(.+?)(?=##|\z)') {
            $synopsis = $matches[1].Trim()
        }

        # Create front matter for Jekyll/Docsy
        $frontMatter = @"
---
layout: page
title: $baseName
permalink: /commands/$baseName
parent: Command Reference
---

"@

        # Combine front matter with content
        $fullContent = $frontMatter + $content

        # Save to destination
        Set-Content -Path $destPath -Value $fullContent -NoNewline

        Write-Host "  ✓ Processed: $fileName" -ForegroundColor Gray
    }
}
else {
    Write-Warning "Build documentation not found at: $buildDocsPath"
}

# Copy README.md from repository root if it exists
$readmePath = "./README.md"
if (Test-Path $readmePath) {
    Write-Host "Processing README.md" -ForegroundColor Green
    $readmeContent = Get-Content -Path $readmePath -Raw

    # Check if getting-started.md already exists (from .ghpages folder)
    $gettingStartedPath = Join-Path $OutputPath "getting-started.md"
    if (-not (Test-Path $gettingStartedPath)) {
        # Add front matter to README and save as getting-started
        $frontMatter = @"
---
layout: page
title: Getting Started
permalink: /getting-started
---

"@

        $fullContent = $frontMatter + $readmeContent
        Set-Content -Path $gettingStartedPath -Value $fullContent
        Write-Host "  ✓ Created getting-started.md from README" -ForegroundColor Gray
    }
}

# Copy any additional docs from repository docs folder
if (Test-Path $RepositoryDocsPath) {
    Write-Host "Copying additional documentation from repository" -ForegroundColor Green
    Get-ChildItem $RepositoryDocsPath -Filter "*.md" -File | ForEach-Object {
        $content = Get-Content -Path $_.FullName -Raw

        # Add front matter if not present
        if ($content -notmatch '^---\s*\n') {
            $frontMatter = @"
---
layout: page
title: $($_.BaseName)
---

"@
            $content = $frontMatter + $content
        }

        $destPath = Join-Path $OutputPath $_.Name
        Set-Content -Path $destPath -Value $content
        Write-Host "  ✓ Copied: $($_.Name)" -ForegroundColor Gray
    }
}

# DO NOT create .nojekyll - we want Jekyll to process with Docsy theme
Write-Host "`nJekyll (Docsy theme) will process the documentation" -ForegroundColor Yellow

# Display summary
Write-Host "`n=== Documentation Preparation Complete ===" -ForegroundColor Cyan
Write-Host "Output directory: $OutputPath" -ForegroundColor Green
Write-Host "`nContents:" -ForegroundColor Yellow
Get-ChildItem $OutputPath -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Replace("$(Resolve-Path $OutputPath)\", "").Replace("$(Resolve-Path $OutputPath)/", "")
    Write-Host "  - $relativePath" -ForegroundColor Gray
}

Write-Host "`n✓ Documentation ready for Jekyll (Docsy) deployment" -ForegroundColor Green
