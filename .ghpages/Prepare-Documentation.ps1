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

# Copy Jekyll configuration files
Write-Host "Copying Jekyll configuration files" -ForegroundColor Green
$configFiles = @('_config.yml', 'index.md', 'getting-started.md', 'examples.md')
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

    # Create a list for the commands index
    $commandsList = @()

    Get-ChildItem $buildDocsPath -Filter "*.md" -File | ForEach-Object {
        $fileName = $_.Name
        $baseName = $_.BaseName
        $destPath = Join-Path "$OutputPath/commands" $fileName

        # Read the content
        $content = Get-Content -Path $_.FullName -Raw

        # Extract synopsis from markdown if available
        $synopsis = ""
        if ($content -match '##\s+SYNOPSIS\s+(.+?)(?=##|\z)') {
            $synopsis = $matches[1].Trim() -replace '\r?\n', ' '
        }

        # Create front matter for Jekyll/Docsy
        $frontMatter = @"
---
title: $baseName
tags:
 - powershell
 - cmdlet
description: $synopsis
---

"@

        # Combine front matter with content
        $fullContent = $frontMatter + $content

        # Save to destination
        Set-Content -Path $destPath -Value $fullContent -NoNewline

        Write-Host "  ✓ Processed: $fileName" -ForegroundColor Gray

        # Add to commands list
        $commandsList += [PSCustomObject]@{
            Name     = $baseName
            Synopsis = $synopsis
            FileName = $fileName
        }
    }

    # Create commands index page
    Write-Host "Creating commands index page" -ForegroundColor Green
    $commandsIndex = @"
---
title: Command Reference
tags:
 - documentation
 - reference
description: Complete reference for all cmdlets in the LeastPrivilegedMSGraph module
---

# Command Reference

Complete reference documentation for all cmdlets in the LeastPrivilegedMSGraph module.

## Available Commands

"@

    # Add table of commands
    $commandsIndex += "`n| Command | Description |`n"
    $commandsIndex += "|---------|-------------|`n"
    foreach ($cmd in ($commandsList | Sort-Object Name)) {
        $commandsIndex += "| [``$($cmd.Name)``](commands/$($cmd.FileName)) | $($cmd.Synopsis) |`n"
    }

    $commandsIndex += @"

## Quick Reference by Category

### Permission Analysis
- [Get-PermissionAnalysis](commands/Get-PermissionAnalysis.md) - Analyze application permissions
- [Export-PermissionAnalysisReport](commands/Export-PermissionAnalysisReport.md) - Export analysis reports

### Application Monitoring
- [Get-AppActivityData](commands/Get-AppActivityData.md) - Retrieve API usage data
- [Get-AppRoleAssignment](commands/Get-AppRoleAssignment.md) - List role assignments
- [Get-AppThrottlingData](commands/Get-AppThrottlingData.md) - Check throttling status

### Configuration
- [Initialize-LogAnalyticsApi](commands/Initialize-LogAnalyticsApi.md) - Setup Log Analytics connection

---

Browse individual command documentation using the table above.
"@

    Set-Content -Path "$OutputPath/commands.md" -Value $commandsIndex
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
title: Getting Started
tags:
 - getting-started
 - installation
description: Installation and setup guide for LeastPrivilegedMSGraph
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
