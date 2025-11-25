---
layout: page
title: Home
permalink: /
---

# LeastPrivilegedMSGraph

PowerShell module for analyzing and determining least privileged permissions for Microsoft Graph applications.

<div markdown="span" class="alert alert-info" role="alert">
<i class="fa fa-info-circle"></i> <b>Current Version:</b> 0.1.0-preview - Available on PowerShell Gallery
</div>

## Quick Start

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
```

## Features

### 🔍 Permission Analysis
Analyze application permissions and determine least privileged access requirements based on actual API usage.

### 📊 Activity Monitoring
Track application API usage patterns and identify throttling issues across your Microsoft Graph applications.

### 📈 Comprehensive Reporting
Generate detailed permission analysis reports with recommendations for optimal security configuration.

### 🔐 Security First
Identify over-privileged applications and get actionable recommendations for minimal required permissions.

## Documentation

<div class="section-index">
    <hr class="panel-line">
    <div class="container-fluid">
        <div class="row">
            <div class="col-md-4">
                <h3><a href="{{ site.baseurl }}/getting-started">Getting Started</a></h3>
                <p>Installation and initial setup guide</p>
            </div>
            <div class="col-md-4">
                <h3><a href="{{ site.baseurl }}/commands">Command Reference</a></h3>
                <p>Complete cmdlet documentation</p>
            </div>
            <div class="col-md-4">
                <h3><a href="{{ site.baseurl }}/examples">Examples</a></h3>
                <p>Common usage scenarios</p>
            </div>
        </div>
    </div>
</div>

## Links

- [GitHub Repository](https://github.com/Mynster9361/Least_Privileged_MSGraph)
- [PowerShell Gallery](https://www.powershellgallery.com/packages/LeastPrivilegedMSGraph)
- [Report Issues](https://github.com/Mynster9361/Least_Privileged_MSGraph/issues)
