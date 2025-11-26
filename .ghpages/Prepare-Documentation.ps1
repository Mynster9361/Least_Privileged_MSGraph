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

.command-header {
    border-left: 4px solid #667eea;
}

.command-header h1 {
    color: var(--primary);
    margin-bottom: 1rem;
    font-size: 2em;
}

.command-nav {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid var(--border);
}

.command-nav a {
    background: var(--bg-light);
    color: var(--text-primary);
    padding: 0.5rem 1rem;
    border-radius: 4px;
    text-decoration: none;
    font-size: 0.9em;
    transition: all 0.3s;
}

.command-nav a:hover {
    background: var(--primary);
    color: white;
}

.command-content {
    border-left: 4px solid var(--info);
}

.doc-section {
    margin: 2rem 0;
    padding: 1.5rem;
    background: var(--bg-light);
    border-radius: 8px;
}

.doc-section h2 {
    color: var(--primary);
    margin: 0 0 1rem 0;
    padding-bottom: 0.5rem;
    border-bottom: 2px solid var(--border);
}

.doc-section.synopsis {
    background: linear-gradient(135deg, rgba(102, 126, 234, 0.1) 0%, rgba(118, 75, 162, 0.1) 100%);
    border-left: 4px solid #667eea;
}

.doc-section.description {
    border-left: 4px solid var(--info);
}

.doc-section.examples {
    border-left: 4px solid var(--success);
}

.doc-section.parameters {
    border-left: 4px solid var(--warning);
}

.doc-section.notes {
    border-left: 4px solid var(--info);
}

.param-block {
    background: var(--code-bg);
    padding: 1rem;
    border-radius: 4px;
    margin: 1rem 0;
    border-left: 3px solid var(--warning);
    font-family: 'Consolas', 'Monaco', monospace;
    font-size: 0.85em;
}

.param-block code {
    background: none;
    padding: 0;
    color: var(--text-secondary);
}

.command-card {
    border-left: 3px solid var(--primary);
}

.command-card:hover {
    border-left-color: #667eea;
}

.command-content h3 {
    color: var(--primary);
    margin: 1.5rem 0 1rem;
    padding-top: 1rem;
    border-top: 1px solid var(--border);
}

.command-content h4 {
    color: var(--text-primary);
    margin: 1rem 0 0.5rem;
}

.doc-section ul {
    list-style-type: none;
    padding-left: 0;
}

.doc-section ul li {
    padding-left: 1.5rem;
    position: relative;
    margin: 0.5rem 0;
}

.doc-section ul li:before {
    content: "▸";
    position: absolute;
    left: 0;
    color: var(--primary);
}

.doc-section.examples pre {
    background: #1a1a1a;
    border-left-color: var(--success);
}

/* Smooth scrolling for anchor links */
html {
    scroll-behavior: smooth;
}

/* Highlight target section when navigated to */
.doc-section:target {
    animation: highlight 2s ease-in-out;
}

@keyframes highlight {
    0% { background: rgba(102, 126, 234, 0.3); }
    100% { background: var(--bg-light); }
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
Import-Module LeastPrivilegedMSGraph

# Initialize and connect
Initialize-LogAnalyticsApi
Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $secret -Service "LogAnalytics", "GraphBeta"

# Analyze permissions
$apps = Get-AppRoleAssignment |
    Get-AppActivityData -WorkspaceId $workspaceId -Days 30 |
    Get-AppThrottlingData -WorkspaceId $workspaceId -Days 30 |
    Get-PermissionAnalysis

# Generate report
Export-PermissionAnalysisReport -AppData $apps -OutputPath ".\report.html"</code></pre>
</div>

<div class="card">
    <h2>✨ Key Features</h2>
    <div class="grid">
        <div class="grid-item">
            <h3>🔍 Permission Analysis</h3>
            <p>Analyzes Microsoft Graph permissions against actual API usage from Log Analytics to determine the minimal permission set required based on real activity patterns.</p>
        </div>
        <div class="grid-item">
            <h3>📊 Activity Monitoring</h3>
            <p>Tracks application API usage patterns over configurable time periods, identifying which endpoints are accessed and with what HTTP methods.</p>
        </div>
        <div class="grid-item">
            <h3>🚦 Throttling Detection</h3>
            <p>Monitors API throttling statistics including 429 errors, success rates, and automatic severity classification to identify performance issues.</p>
        </div>
        <div class="grid-item">
            <h3>📈 Interactive Reports</h3>
            <p>Generates beautiful, self-contained HTML reports with filtering, sorting, and detailed visualizations of permission usage and recommendations.</p>
        </div>
        <div class="grid-item">
            <h3>🔐 Security First</h3>
            <p>Identifies over-privileged applications with unused permissions and provides actionable recommendations for implementing least privilege access.</p>
        </div>
        <div class="grid-item">
            <h3>⚡ Pipeline-Friendly</h3>
            <p>Designed for PowerShell pipeline operations with efficient batch processing for analyzing hundreds of applications at once.</p>
        </div>
    </div>
</div>

<div class="card">
    <h2>📖 Documentation</h2>
    <a href="getting-started.html" class="btn">🚀 Getting Started Guide</a>
    <a href="commands.html" class="btn">📚 Command Reference</a>
    <a href="https://github.com/Mynster9361/Least_Privileged_MSGraph" class="btn" target="_blank">💻 GitHub Repository</a>
    <a href="https://www.powershellgallery.com/packages/LeastPrivilegedMSGraph" class="btn" target="_blank">📦 PowerShell Gallery</a>
</div>

<div class="card">
    <h2>🎯 Why LeastPrivilegedMSGraph?</h2>
    <ul>
        <li><strong>Evidence-Based Analysis:</strong> Recommendations based on actual API usage from Azure Log Analytics, not guesswork or assumptions</li>
        <li><strong>Comprehensive Coverage:</strong> Analyzes permissions, activity, and throttling in a single unified workflow</li>
        <li><strong>Interactive Reporting:</strong> Beautiful HTML reports with real-time filtering, sorting, and detailed permission breakdowns</li>
        <li><strong>Batch Processing:</strong> Efficiently analyze multiple applications with automatic pagination and progress tracking</li>
        <li><strong>Health Monitoring:</strong> Track throttling and performance issues alongside permission analysis</li>
        <li><strong>Best Practices:</strong> Follows Microsoft security recommendations and implements greedy set cover algorithm for optimal permission sets</li>
        <li><strong>Production Ready:</strong> Enterprise-tested with comprehensive error handling and verbose logging</li>
    </ul>
</div>

<div class="card">
    <h2>🛠️ What It Does</h2>
    <p>LeastPrivilegedMSGraph helps you implement the principle of least privilege for Microsoft Graph API permissions by:</p>
    <ol>
        <li><strong>Retrieving Current Permissions:</strong> Gets all app role assignments for Microsoft Graph across your tenant</li>
        <li><strong>Analyzing Activity:</strong> Queries Log Analytics for actual API calls made by each application</li>
        <li><strong>Monitoring Health:</strong> Collects throttling statistics to identify performance issues</li>
        <li><strong>Calculating Optimal Permissions:</strong> Uses permission mapping and set cover algorithm to determine minimal required permissions</li>
        <li><strong>Identifying Gaps:</strong> Highlights excess permissions that can be removed and missing permissions that should be added</li>
        <li><strong>Generating Reports:</strong> Creates interactive HTML reports for review, compliance, and change requests</li>
    </ol>
</div>

<div class="card">
    <h2>📋 Use Cases</h2>
    <div class="grid">
        <div class="grid-item">
            <h3>🔒 Security Hardening</h3>
            <p>Identify and remove unnecessary permissions to reduce attack surface and improve security posture across all Graph API applications.</p>
        </div>
        <div class="grid-item">
            <h3>✅ Compliance Audits</h3>
            <p>Generate evidence-based reports demonstrating least privilege implementation for SOC 2, ISO 27001, and other compliance frameworks.</p>
        </div>
        <div class="grid-item">
            <h3>🔄 Permission Right-Sizing</h3>
            <p>Optimize permission grants based on actual usage patterns, removing over-privileging while ensuring applications have what they need.</p>
        </div>
        <div class="grid-item">
            <h3>📊 Governance Monitoring</h3>
            <p>Regularly review permission usage to detect drift, unused apps, and potential security issues before they become problems.</p>
        </div>
        <div class="grid-item">
            <h3>🎫 Change Requests</h3>
            <p>Generate detailed reports with specific permission recommendations to attach to change requests and approval workflows.</p>
        </div>
        <div class="grid-item">
            <h3>🚨 Incident Response</h3>
            <p>Quickly identify which applications have access to sensitive data during security incidents or breach investigations.</p>
        </div>
    </div>
</div>

<div class="card">
    <h2>🏗️ Module Architecture</h2>
    <p>The module follows a pipeline-based architecture with six main cmdlets:</p>
    <ul>
        <li><code>Initialize-LogAnalyticsApi</code> - Registers Log Analytics service for authentication</li>
        <li><code>Get-AppRoleAssignment</code> - Retrieves current Microsoft Graph permissions for all applications</li>
        <li><code>Get-AppActivityData</code> - Enriches applications with API activity from Log Analytics</li>
        <li><code>Get-AppThrottlingData</code> - Adds throttling statistics and health metrics</li>
        <li><code>Get-PermissionAnalysis</code> - Analyzes permissions against activity to determine optimal set</li>
        <li><code>Export-PermissionAnalysisReport</code> - Generates interactive HTML reports</li>
    </ul>
</div>

<div class="card">
    <h2>🎓 Learn More</h2>
    <ul>
        <li><a href="getting-started.html">📚 Getting Started Tutorial</a> - Step-by-step guide with examples</li>
        <li><a href="commands.html">🔧 Complete Command Reference</a> - Detailed documentation for all cmdlets</li>
        <li><a href="https://github.com/Mynster9361/Least_Privileged_MSGraph/blob/main/README.md" target="_blank">📖 Full README</a> - Comprehensive overview and architecture</li>
        <li><a href="https://github.com/Mynster9361/Least_Privileged_MSGraph/issues" target="_blank">🐛 Report Issues</a> - Bug reports and feature requests</li>
    </ul>
</div>

<div class="card">
    <h2>⚙️ Prerequisites</h2>
    <ul>
        <li>PowerShell 5.1 or later</li>
        <li>Azure Log Analytics workspace with Microsoft Graph activity logs enabled <a href="https://learn.microsoft.com/en-us/graph/microsoft-graph-activity-logs-overview" target="_blank">Learn more (MS DOCS)</a></li>
        <li>Azure AD App Registration with required permissions:
            <ul>
                <li><code>Application.Read.All</code> - To read service principals</li>
                <li><code>AppRoleAssignment.Read.All</code> - To read permission assignments</li>
                <li><code>Log Analytics Reader</code> role on the workspace</li>
            </ul>
        </li>
    </ul>
</div>

<div class="card">
    <h2>🤝 Contributing</h2>
    <p>Contributions are welcome! This is an open-source project under the MIT License.</p>
    <ul>
        <li>Fork the repository and create feature branches</li>
        <li>Follow the existing code style and documentation standards</li>
        <li>Add Pester tests for new functionality</li>
        <li>Update documentation and examples</li>
        <li>Submit pull requests with detailed descriptions</li>
    </ul>
    <a href="https://github.com/Mynster9361/Least_Privileged_MSGraph/blob/main/CONTRIBUTING.md" class="btn" target="_blank">Contributing Guidelines</a>
</div>
'@

$indexHtml = New-HtmlPage -Title "Home" -Content $indexContent -RelativePath "."
Set-Content -Path "$OutputPath/index.html" -Value $indexHtml

# Create getting-started.html
Write-Host "Creating getting-started.html" -ForegroundColor Green
$gettingStartedContent = @'
<div class="card">
    <h2>Installation</h2>
    <pre><code>Install-Module -Name LeastPrivilegedMSGraph -Repository PSGallery
Import-Module LeastPrivilegedMSGraph</code></pre>
</div>

<div class="card">
    <h2>Prerequisites</h2>
    <ul>
        <li>PowerShell 5.1 or later</li>
        <li>Azure Log Analytics workspace with Microsoft Graph activity logs enabled <a href="https://learn.microsoft.com/en-us/graph/microsoft-graph-activity-logs-overview" target="_blank">Learn more (MS DOCS)</a></li>
        <li>Azure AD App Registration with:
            <ul>
                <li><code>Application.Read.All</code> permission</li>
                <li><code>AppRoleAssignment.Read.All</code> permission</li>
                <li>Log Analytics Reader role on the workspace</li>
            </ul>
        </li>
    </ul>
</div>

<div class="card">
    <h2>Quick Start Example</h2>
    <h3>1. Setup Credentials</h3>
    <pre><code># Define your Azure AD app and workspace details
$tenantId = "12345678-1234-1234-1234-123456789012"
$clientId = "87654321-4321-4321-4321-210987654321"
$clientSecret = "your-client-secret-here" | ConvertTo-SecureString -AsPlainText -Force
$workspaceId = "abcdef00-1111-2222-3333-444444444444"
$daysToAnalyze = 30</code></pre>

    <h3>2. Initialize and Connect</h3>
    <pre><code># Initialize Log Analytics API service
Initialize-LogAnalyticsApi

# Connect to both Microsoft Graph and Log Analytics
$connectSplat = @{
    ClientID     = $clientId
    TenantID     = $tenantId
    ClientSecret = $clientSecret
    Service      = "LogAnalytics", "GraphBeta"
}
Connect-EntraService @connectSplat
</code></pre>

    <h3>3. Analyze Permissions</h3>
    <pre><code># Get all apps with Graph permissions
$apps = Get-AppRoleAssignment

# Add API activity data from Log Analytics
$apps | Get-AppActivityData -WorkspaceId $workspaceId -Days $daysToAnalyze

# Add throttling statistics
$apps | Get-AppThrottlingData -WorkspaceId $workspaceId -Days $daysToAnalyze

# Perform permission analysis
$analysis = $apps | Get-PermissionAnalysis

# Generate interactive HTML report
Export-PermissionAnalysisReport -AppData $analysis -OutputPath ".\PermissionReport.html"</code></pre>

    <h3>4. View Results</h3>
    <pre><code># Open the report in your default browser
Invoke-Item ".\PermissionReport.html"

# Or review in PowerShell
$analysis | Where-Object { $_.ExcessPermissions.Count -gt 0 } |
    Select-Object PrincipalName,
                  @{N='Current';E={$_.CurrentPermissions.Count}},
                  @{N='Optimal';E={$_.OptimalPermissions.Count}},
                  @{N='Excess';E={$_.ExcessPermissions.Count}} |
    Format-Table -AutoSize</code></pre>
</div>

<div class="card">
    <h2>Complete Workflow Example</h2>
    <pre><code># Complete permission analysis workflow
$tenantId = "12345678-1234-1234-1234-123456789012"
$clientId = "87654321-4321-4321-4321-210987654321"
$clientSecret = "your-secret" | ConvertTo-SecureString -AsPlainText -Force
$workspaceId = "abcdef00-1111-2222-3333-444444444444"

# Setup
Import-Module LeastPrivilegedMSGraph
Initialize-LogAnalyticsApi
$connectSplat = @{
    ClientID     = $clientId
    TenantID     = $tenantId
    ClientSecret = $clientSecret
    Service      = "LogAnalytics", "GraphBeta"
}

Connect-EntraService @connectSplat

# Analysis pipeline
$results = Get-AppRoleAssignment |
    Get-AppActivityData -WorkspaceId $workspaceId -Days 30 |
    Get-AppThrottlingData -WorkspaceId $workspaceId -Days 30 |
    Get-PermissionAnalysis

# Generate report
Export-PermissionAnalysisReport -AppData $results -OutputPath ".\analysis-$(Get-Date -Format 'yyyyMMdd').html"

# Display summary
"`nAnalysis Complete!"
"Applications analyzed: $($results.Count)"
"Over-privileged apps: $(($results | Where-Object { $_.ExcessPermissions.Count -gt 0 }).Count)"
"Total excess permissions: $(($results.ExcessPermissions | Measure-Object).Count)"
</code></pre>
</div>

<div class="card">
    <h2>Analyzing Specific Applications</h2>
    <pre><code># Analyze only specific applications
$criticalApps = Get-AppRoleAssignment |
    Where-Object { $_.PrincipalName -like "*Production*" }

$analysis = $criticalApps |
    Get-AppActivityData -WorkspaceId $workspaceId -Days 90 |
    Get-AppThrottlingData -WorkspaceId $workspaceId -Days 90 |
    Get-PermissionAnalysis

# Find apps with high-privilege permissions they don't use
$dangerousPerms = @('Directory.ReadWrite.All', 'RoleManagement.ReadWrite.Directory')
$overPrivileged = $analysis | Where-Object {
    $excessive = $_.ExcessPermissions | Where-Object { $_ -in $dangerousPerms }
    $excessive.Count -gt 0
}

if ($overPrivileged) {
    Write-Warning "Found $($overPrivileged.Count) apps with unused high-privilege permissions!"
    $overPrivileged | Select-Object PrincipalName, @{N='UnusedHighPrivPerms';E={$_.ExcessPermissions | Where-Object { $_ -in $dangerousPerms }}}
}</code></pre>
</div>

<div class="card">
    <h2>Troubleshooting</h2>
    <h3>Connection Issues</h3>
    <pre><code># Test Log Analytics connectivity
Initialize-LogAnalyticsApi
Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret -Service "LogAnalytics"

# Verify you can query the workspace
$testQuery = @{
    query = "MicrosoftGraphActivityLogs | take 1"
}
Invoke-EntraRequest -Service 'LogAnalytics' -ApiUrl "/v1/workspaces/$workspaceId/query" -Method POST -Body $testQuery</code></pre>

    <h3>No Activity Data</h3>
    <ul>
        <li>Verify Microsoft Graph diagnostic settings are enabled</li>
        <li>Check logs are flowing: Azure Portal > Log Analytics > Logs > Run: <code>MicrosoftGraphActivityLogs | take 10</code></li>
        <li>Increase <code>-Days</code> parameter (applications may have infrequent activity)</li>
        <li>Ensure service principal has made API calls in the time period</li>
    </ul>

    <h3>Permission Errors</h3>
    <pre><code># Verify your app has required permissions
Get-MgServicePrincipal -Filter "appId eq '$clientId'" |
    Select-Object -ExpandProperty AppRoles |
    Where-Object { $_.Value -in @('Application.Read.All', 'AppRoleAssignment.Read.All') }</code></pre>
</div>

<div class="card">
    <h2>Next Steps</h2>
    <ul>
        <li><a href="commands.html">📚 Explore all available commands</a></li>
        <li><a href="https://github.com/Mynster9361/Least_Privileged_MSGraph/blob/main/README.md" target="_blank">📖 Read the full documentation</a></li>
        <li><a href="https://github.com/Mynster9361/Least_Privileged_MSGraph/issues" target="_blank">🐛 Report issues or request features</a></li>
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

        # Remove YAML front matter
        $content = $content -replace '(?s)^---.*?---\s*', ''

        # Convert markdown headers to HTML with IDs for navigation
        $content = $content -replace '(?m)^## (.+)$', '<h2 id="$1">$1</h2>'
        $content = $content -replace '(?m)^### (.+)$', '<h3>$1</h3>'
        $content = $content -replace '(?m)^#### (.+)$', '<h4>$1</h4>'

        # Convert code blocks - PowerShell
        $content = $content -replace '(?s)```powershell\s*\n(.+?)\n```', '<pre><code class="language-powershell">$1</code></pre>'

        # Convert code blocks - YAML (for parameter blocks)
        $content = $content -replace '(?s)```yaml\s*\n(.+?)\n```', '<div class="param-block"><code>$1</code></div>'

        # Convert generic code blocks
        $content = $content -replace '(?s)```\s*\n(.+?)\n```', '<pre><code>$1</code></pre>'

        # Convert inline code
        $content = $content -replace '`([^`]+)`', '<code>$1</code>'

        # Convert bold and italic
        $content = $content -replace '\*\*(.+?)\*\*', '<strong>$1</strong>'
        $content = $content -replace '\*(.+?)\*', '<em>$1</em>'

        # Convert links
        $content = $content -replace '\[([^\]]+)\]\(([^\)]+)\)', '<a href="$2" target="_blank">$1</a>'

        # Convert bullet lists
        $content = $content -replace '(?m)^- (.+)$', '<li>$1</li>'
        $content = $content -replace '(?s)(<li>.*?</li>)', '<ul>$1</ul>'

        # Clean up nested lists
        $content = $content -replace '</ul>\s*<ul>', ''

        # Wrap in semantic sections
        $sections = @{
            'SYNOPSIS'      = 'synopsis'
            'SYNTAX'        = 'syntax'
            'DESCRIPTION'   = 'description'
            'PARAMETERS'    = 'parameters'
            'INPUTS'        = 'inputs'
            'OUTPUTS'       = 'outputs'
            'EXAMPLES'      = 'examples'
            'NOTES'         = 'notes'
            'RELATED LINKS' = 'related-links'
        }

        foreach ($section in $sections.GetEnumerator()) {
            $sectionClass = $section.Value
            $content = $content -replace "<h2 id=`"$($section.Key)`">$($section.Key)</h2>",
            "<div class='doc-section $sectionClass'><h2 id=`"$($section.Key)`">$($section.Key)</h2>"

            # Close previous section if exists
            if ($content -match "<div class='doc-section") {
                $content = $content -replace "(<div class='doc-section [^>]+>)", "</div>`$1"
            }
        }

        # Close final section
        $content += "</div>"

        # Remove first closing div (artifact from replacement)
        $content = $content -replace '^</div>', '', 1

        # Create command page with navigation
        $commandNav = @"
<div class="command-nav">
    <a href="#SYNOPSIS">Synopsis</a>
    <a href="#SYNTAX">Syntax</a>
    <a href="#DESCRIPTION">Description</a>
    <a href="#PARAMETERS">Parameters</a>
    <a href="#EXAMPLES">Examples</a>
    <a href="#NOTES">Notes</a>
    <a href="#RELATED LINKS">Related Links</a>
</div>
"@

        $pageContent = @"
<div class="card command-header">
    <h1>$baseName</h1>
    $commandNav
</div>
<div class="card command-content">
    $content
</div>
"@

        $page = New-HtmlPage -Title $baseName -Content $pageContent -RelativePath ".."
        Set-Content -Path "$OutputPath/commands/$baseName.html" -Value $page

        # Extract synopsis for commands list
        $synopsis = ""
        if ($content -match '<div class=.doc-section synopsis.>.*?<p>(.+?)</p>') {
            $synopsis = $matches[1] -replace '<[^>]+>', '' # Strip HTML tags
        }

        $commandsList += [PSCustomObject]@{
            Name     = $baseName
            Synopsis = if ($synopsis) {
                $synopsis
            }
            else {
                "PowerShell command from LeastPrivilegedMSGraph module"
            }
        }

        Write-Host "  ✓ $baseName.html" -ForegroundColor Gray
    }

    # Create commands index with better styling
    $commandsListHtml = $commandsList | Sort-Object Name | ForEach-Object {
        @"
<div class="grid-item command-card">
    <h3><a href="commands/$($_.Name).html">📌 $($_.Name)</a></h3>
    <p>$($_.Synopsis)</p>
</div>
"@
    }

    $commandsContent = @"
<div class="card">
    <h2>📚 Command Reference</h2>
    <p>Complete reference for all $($commandsList.Count) cmdlets in the LeastPrivilegedMSGraph module.</p>
    <input type="text" id="search" placeholder="🔍 Search commands..." style="width: 100%; padding: 0.75rem; margin: 1rem 0; background: var(--bg-light); border: 1px solid var(--border); border-radius: 5px; color: var(--text-primary); font-size: 1em;">
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
