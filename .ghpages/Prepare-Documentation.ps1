<#
.SYNOPSIS
    Prepares static HTML documentation for GitHub Pages deployment.
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

Write-Host "=== Preparing Static HTML Documentation ===" -ForegroundColor Cyan

# Create output directory
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
New-Item -ItemType Directory -Path "$OutputPath/commands" -Force | Out-Null
New-Item -ItemType Directory -Path "$OutputPath/css" -Force | Out-Null
New-Item -ItemType Directory -Path "$OutputPath/js" -Force | Out-Null

# Create .nojekyll to skip Jekyll processing
New-Item -Path "$OutputPath/.nojekyll" -ItemType File -Force | Out-Null
Write-Host "✓ Created .nojekyll file" -ForegroundColor Green

# CSS Stylesheet
$css = @'
:root {
    --primary: #0078d4;
    --primary-dark: #005a9e;
    --bg-dark: #1e1e1e;
    --bg-medium: #2d2d2d;
    --bg-light: #3a3a3a;
    --text-primary: #e0e0e0;
    --text-secondary: #b0b0b0;
    --border: #404040;
    --success: #4caf50;
    --warning: #ff9800;
    --info: #2196f3;
    --code-bg: #2d2d2d;
}

* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background: var(--bg-dark);
    color: var(--text-primary);
    line-height: 1.6;
}

header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    padding: 2rem 0;
    box-shadow: 0 2px 10px rgba(0,0,0,0.3);
}

header .container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 20px;
}

header h1 {
    color: white;
    font-size: 2.5em;
    margin-bottom: 0.5rem;
}

header p {
    color: rgba(255,255,255,0.9);
    font-size: 1.2em;
}

nav {
    background: var(--bg-medium);
    padding: 1rem 0;
    border-bottom: 3px solid var(--primary);
    position: sticky;
    top: 0;
    z-index: 100;
}

nav ul {
    list-style: none;
    display: flex;
    justify-content: center;
    gap: 2rem;
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 20px;
}

nav a {
    color: var(--text-primary);
    text-decoration: none;
    font-weight: 500;
    transition: color 0.3s;
    padding: 0.5rem 1rem;
    border-radius: 4px;
}

nav a:hover {
    color: var(--primary);
    background: var(--bg-light);
}

.container {
    max-width: 1200px;
    margin: 2rem auto;
    padding: 0 20px;
}

.card {
    background: var(--bg-medium);
    border-radius: 8px;
    padding: 2rem;
    margin-bottom: 2rem;
    border-left: 4px solid var(--primary);
    box-shadow: 0 2px 8px rgba(0,0,0,0.2);
}

.card h2 {
    color: var(--primary);
    margin-bottom: 1rem;
}

.card h3 {
    color: var(--text-primary);
    margin: 1.5rem 0 1rem;
}

.grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 1.5rem;
    margin-top: 1.5rem;
}

.grid-item {
    background: var(--bg-medium);
    padding: 1.5rem;
    border-radius: 8px;
    border: 1px solid var(--border);
    transition: all 0.3s;
}

.grid-item:hover {
    transform: translateY(-4px);
    border-color: var(--primary);
    box-shadow: 0 4px 12px rgba(0,120,212,0.2);
}

.grid-item h3 {
    color: var(--primary);
    margin: 0 0 0.5rem 0;
}

.grid-item a {
    color: var(--primary);
    text-decoration: none;
    font-weight: 500;
}

.grid-item a:hover {
    text-decoration: underline;
}

code {
    background: var(--code-bg);
    padding: 0.2rem 0.4rem;
    border-radius: 3px;
    font-family: 'Consolas', 'Monaco', monospace;
    color: #a8e6cf;
    font-size: 0.9em;
}

pre {
    background: var(--code-bg);
    padding: 1.5rem;
    border-radius: 5px;
    overflow-x: auto;
    margin: 1rem 0;
    border-left: 3px solid var(--primary);
}

pre code {
    background: none;
    padding: 0;
    font-size: 0.95em;
}

.btn {
    display: inline-block;
    background: var(--primary);
    color: white;
    padding: 0.75rem 1.5rem;
    text-decoration: none;
    border-radius: 5px;
    margin: 0.5rem 0.5rem 0.5rem 0;
    transition: background 0.3s;
    font-weight: 500;
}

.btn:hover {
    background: var(--primary-dark);
}

.badge {
    display: inline-block;
    padding: 0.25rem 0.5rem;
    border-radius: 3px;
    font-size: 0.85em;
    font-weight: 500;
    margin-right: 0.5rem;
}

.badge-primary { background: var(--primary); color: white; }
.badge-success { background: var(--success); color: white; }
.badge-info { background: var(--info); color: white; }

ul, ol {
    margin: 1rem 0 1rem 2rem;
}

li {
    margin: 0.5rem 0;
}

footer {
    text-align: center;
    padding: 3rem 0;
    margin-top: 4rem;
    border-top: 1px solid var(--border);
    color: var(--text-secondary);
}

@media (max-width: 768px) {
    header h1 { font-size: 2em; }
    header p { font-size: 1em; }
    nav ul { flex-direction: column; gap: 0.5rem; }
    .grid { grid-template-columns: 1fr; }
}
'@

Set-Content -Path "$OutputPath/css/style.css" -Value $css
Write-Host "✓ Created CSS stylesheet" -ForegroundColor Green

# JavaScript for search/filter
$js = @'
document.addEventListener('DOMContentLoaded', function() {
    const searchInput = document.getElementById('search');
    if (searchInput) {
        searchInput.addEventListener('input', function(e) {
            const searchTerm = e.target.value.toLowerCase();
            const items = document.querySelectorAll('.grid-item');

            items.forEach(item => {
                const text = item.textContent.toLowerCase();
                item.style.display = text.includes(searchTerm) ? 'block' : 'none';
            });
        });
    }
});
'@

Set-Content -Path "$OutputPath/js/main.js" -Value $js

# HTML Template Function
function New-HtmlPage {
    param(
        [string]$Title,
        [string]$Content,
        [string]$RelativePath = ".."
    )

    return @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="LeastPrivilegedMSGraph - PowerShell module for analyzing Microsoft Graph permissions">
    <title>$Title - LeastPrivilegedMSGraph</title>
    <link rel="stylesheet" href="$RelativePath/css/style.css">
</head>
<body>
    <header>
        <div class="container">
            <h1>🔐 LeastPrivilegedMSGraph</h1>
            <p>PowerShell module for analyzing Microsoft Graph permissions</p>
        </div>
    </header>

    <nav>
        <ul>
            <li><a href="$RelativePath/index.html">🏠 Home</a></li>
            <li><a href="$RelativePath/getting-started.html">🚀 Getting Started</a></li>
            <li><a href="$RelativePath/commands.html">📚 Commands</a></li>
            <li><a href="https://github.com/Mynster9361/Least_Privileged_MSGraph" target="_blank">💻 GitHub</a></li>
            <li><a href="https://www.powershellgallery.com/packages/LeastPrivilegedMSGraph" target="_blank">📦 Gallery</a></li>
        </ul>
    </nav>

    <div class="container">
        $Content
    </div>

    <footer>
        <p>&copy; 2025 LeastPrivilegedMSGraph | MIT License</p>
        <p>Built with ❤️ for the PowerShell community</p>
    </footer>
    <script src="$RelativePath/js/main.js"></script>
</body>
</html>
"@
}

# Create index.html
Write-Host "Creating index.html" -ForegroundColor Green
$indexContent = @'
<div class="card">
    <h2>🚀 Quick Start</h2>
    <pre><code>Install-Module -Name LeastPrivilegedMSGraph -Repository PSGallery
Import-Module LeastPrivilegedMSGraph</code></pre>
</div>

<div class="card">
    <h2>✨ Key Features</h2>
    <div class="grid">
        <div class="grid-item">
            <h3>🔍 Permission Analysis</h3>
            <p>Analyze application permissions and determine least privileged access requirements based on actual API usage.</p>
        </div>
        <div class="grid-item">
            <h3>📊 Activity Monitoring</h3>
            <p>Track application API usage patterns and identify throttling issues across your Microsoft Graph applications.</p>
        </div>
        <div class="grid-item">
            <h3>📈 Comprehensive Reporting</h3>
            <p>Generate detailed permission analysis reports with recommendations for optimal security configuration.</p>
        </div>
        <div class="grid-item">
            <h3>🔐 Security First</h3>
            <p>Identify over-privileged applications and get actionable recommendations for minimal required permissions.</p>
        </div>
    </div>
</div>

<div class="card">
    <h2>📖 Documentation</h2>
    <a href="getting-started.html" class="btn">Getting Started Guide</a>
    <a href="commands.html" class="btn">Command Reference</a>
    <a href="https://github.com/Mynster9361/Least_Privileged_MSGraph/blob/main/README.md" class="btn" target="_blank">Full Documentation</a>
</div>

<div class="card">
    <h2>🎯 Why LeastPrivilegedMSGraph?</h2>
    <ul>
        <li><strong>Evidence-Based:</strong> Recommendations based on actual API usage from Log Analytics</li>
        <li><strong>Interactive Reports:</strong> Beautiful HTML reports with filtering and sorting</li>
        <li><strong>Batch Processing:</strong> Analyze multiple applications efficiently</li>
        <li><strong>Health Monitoring:</strong> Track throttling and performance issues</li>
        <li><strong>Best Practices:</strong> Follows Microsoft security recommendations</li>
    </ul>
</div>
'@

$indexHtml = New-HtmlPage -Title "Home" -Content $indexContent -RelativePath "."
Set-Content -Path "$OutputPath/index.html" -Value $indexHtml

# Create getting-started.html
Write-Host "Creating getting-started.html" -ForegroundColor Green
$gettingStartedContent = @'
<div class="card">
    <h2>Installation</h2>
    <pre><code>Install-Module -Name LeastPrivilegedMSGraph -Repository PSGallery</code></pre>
</div>

<div class="card">
    <h2>Prerequisites</h2>
    <ul>
        <li>PowerShell 5.1 or later</li>
        <li>Azure Log Analytics workspace with Microsoft Graph activity logs</li>
        <li>Appropriate permissions to read Log Analytics data</li>
    </ul>
</div>

<div class="card">
    <h2>Quick Start Example</h2>
    <pre><code># Import the module
Import-Module LeastPrivilegedMSGraph

# Initialize Log Analytics API
Initialize-LogAnalyticsApi -WorkspaceId "your-workspace-id" -SharedKey "your-shared-key"

# Get permission analysis for an application
$analysis = Get-PermissionAnalysis -ApplicationId "your-application-id"

# Export to HTML report
Export-PermissionAnalysisReport -AnalysisData $analysis -OutputPath "./report.html"</code></pre>
</div>

<div class="card">
    <h2>Next Steps</h2>
    <ul>
        <li><a href="commands.html">Explore all available commands</a></li>
        <li><a href="https://github.com/Mynster9361/Least_Privileged_MSGraph/blob/main/README.md" target="_blank">Read the full documentation</a></li>
        <li><a href="https://github.com/Mynster9361/Least_Privileged_MSGraph/issues" target="_blank">Report issues or request features</a></li>
    </ul>
</div>
'@

$gettingStartedHtml = New-HtmlPage -Title "Getting Started" -Content $gettingStartedContent -RelativePath "."
Set-Content -Path "$OutputPath/getting-started.html" -Value $gettingStartedHtml

# Process command docs
$buildDocsPath = Join-Path $BuildOutputPath "docs"
$commandsList = @()

if (Test-Path $buildDocsPath) {
    Write-Host "Processing command documentation" -ForegroundColor Green

    Get-ChildItem $buildDocsPath -Filter "*.md" -File | ForEach-Object {
        $baseName = $_.BaseName
        $content = Get-Content -Path $_.FullName -Raw

        # Convert markdown to HTML
        $htmlContent = $content `
            -replace '##\s+(.+)', '<h2>$1</h2>' `
            -replace '###\s+(.+)', '<h3>$1</h3>' `
            -replace '```powershell\s*\n(.+?)\n```', '<pre><code>$1</code></pre>' `
            -replace '```\s*\n(.+?)\n```', '<pre><code>$1</code></pre>' `
            -replace '`([^`]+)`', '<code>$1</code>' `
            -replace '\*\*(.+?)\*\*', '<strong>$1</strong>' `
            -replace '\*(.+?)\*', '<em>$1</em>'

        $pageContent = "<div class='card'>$htmlContent</div>"
        $page = New-HtmlPage -Title $baseName -Content $pageContent -RelativePath ".."

        Set-Content -Path "$OutputPath/commands/$baseName.html" -Value $page

        # Extract synopsis for commands list
        $synopsis = ""
        if ($content -match '##\s+SYNOPSIS\s+(.+?)(?=##|\z)') {
            $synopsis = $matches[1].Trim() -replace '\r?\n', ' '
        }

        $commandsList += [PSCustomObject]@{
            Name     = $baseName
            Synopsis = $synopsis
        }

        Write-Host "  ✓ $baseName.html" -ForegroundColor Gray
    }

    # Create commands index
    $commandsListHtml = $commandsList | ForEach-Object {
        @"
<div class="grid-item">
    <h3><a href="commands/$($_.Name).html">$($_.Name)</a></h3>
    <p>$($_.Synopsis)</p>
</div>
"@
    }

    $commandsContent = @"
<div class="card">
    <h2>Command Reference</h2>
    <p>Complete reference for all cmdlets in the LeastPrivilegedMSGraph module.</p>
    <input type="text" id="search" placeholder="Search commands..." style="width: 100%; padding: 0.75rem; margin: 1rem 0; background: var(--bg-light); border: 1px solid var(--border); border-radius: 5px; color: var(--text-primary); font-size: 1em;">
</div>

<div class="grid">
    $($commandsListHtml -join "`n")
</div>
"@

    $commandsPage = New-HtmlPage -Title "Commands" -Content $commandsContent -RelativePath "."
    Set-Content -Path "$OutputPath/commands.html" -Value $commandsPage
}

Write-Host "`n✓ Static HTML documentation complete!" -ForegroundColor Green
Write-Host "  Files created: $(( Get-ChildItem $OutputPath -Recurse -File).Count)" -ForegroundColor Gray
