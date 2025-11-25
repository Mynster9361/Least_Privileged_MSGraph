---
layout: page
title: LeastPrivilegedMSGraph
permalink: /
---

# LeastPrivilegedMSGraph

PowerShell module for analyzing and determining least privileged permissions for Microsoft Graph applications.

{% include alert.html type="info" title="Current Version" content="Version 0.1.0-preview - Available on PowerShell Gallery" %}

## 🚀 Quick Start

### Installation

```powershell
Install-Module -Name LeastPrivilegedMSGraph -Repository PSGallery
```

### Basic Usage

```powershell
# Import the module
Import-Module LeastPrivilegedMSGraph

# Initialize Log Analytics API
Initialize-LogAnalyticsApi -WorkspaceId "your-workspace-id" -SharedKey "your-shared-key"

# Get permission analysis for an application
Get-PermissionAnalysis -ApplicationId "your-application-id"

# Export detailed report
Export-PermissionAnalysisReport -ApplicationId "your-app-id" -OutputPath "./reports"
```

## ✨ Features

<div class="row">
  <div class="col-md-6">
    <h3>🔍 Permission Analysis</h3>
    <p>Analyze application permissions and determine least privileged access requirements based on actual API usage.</p>
  </div>
  <div class="col-md-6">
    <h3>📊 Activity Monitoring</h3>
    <p>Track application API usage patterns and identify throttling issues across your Microsoft Graph applications.</p>
  </div>
</div>

<div class="row">
  <div class="col-md-6">
    <h3>📈 Comprehensive Reporting</h3>
    <p>Generate detailed permission analysis reports with recommendations for optimal security configuration.</p>
  </div>
  <div class="col-md-6">
    <h3>🔐 Security First</h3>
    <p>Identify over-privileged applications and get actionable recommendations for minimal required permissions.</p>
  </div>
</div>

## 📚 Documentation

- **[Getting Started](getting-started)** - Installation and initial setup
- **[Command Reference](commands)** - Complete cmdlet documentation
- **[Examples](examples)** - Common usage scenarios and code samples

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/Mynster9361/Least_Privileged_MSGraph/blob/main/LICENSE) file for details.

## 🔗 Links

- [GitHub Repository](https://github.com/Mynster9361/Least_Privileged_MSGraph)
- [PowerShell Gallery](https://www.powershellgallery.com/packages/LeastPrivilegedMSGraph)
- [Report Issues](https://github.com/Mynster9361/Least_Privileged_MSGraph/issues)
