# Changelog for LeastPrivilegedMSGraph

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]

### Added
- **New Cmdlets:**
  - `Assert-LPMSGraph` - Validates all prerequisites before running analysis (EntraAuth connectivity, workspace configuration, required modules)
  - `Invoke-LPMSGraphScan` - Single orchestration command that executes the complete least privilege analysis workflow
    - Supports both workspace ID and detailed workspace parameters (subscription, resource group, workspace name)
    - Includes optional throttling data collection
    - Automatically chains all analysis steps: role assignments → activity data → throttling data → permission analysis → report generation
- **User Context Support:**
  - Module now supports delegated (user) authentication context in addition to app-only (service principal) authentication
  - Enhanced flexibility for different authentication scenarios and permission models


### Acknowledgments
Thanks to Jos Lieben (jflieben) for the suggestion


## [1.0.0] - 2025-12-15

### Added
- **PSFramework Integration:**
  - Utilizing the logging functionality along with runspace management
  - Provides significantly faster results (2x performance improvement even with the bug fix implemented)
- **GitHub Pages Documentation:**
  - Interactive command reference with searchable documentation
  - Modern dark-themed documentation site with responsive design
  - Comprehensive getting started guide
  - Workflow examples demonstrating common use cases
- **Get-AppActivityData:**
  - Introduce 3 new parameters
    - `-ThrottleLimit` allows you to specify a certain amount of runspaces so it gathers multiple app data at once. Recommended setting is between 5-20; higher values use more resources
    - `-MaxActivityEntries` This parameter allows you to specify how much data you want to base your analysis on. For example, you can look back 30 days but some apps might have sent 20 million requests in that timeframe. This parameter allows you to specify how many requests from the last 30 days to analyze. This speeds up analysis significantly, useful for quick overviews, but note that you might not capture all endpoints. Default is 100,000 requests per app
    - `-retainRawUri` Interested in the specific URLs your apps are hitting? This switch allows you to retain the raw URL instead of anonymizing it. Note that if you use this switch you will not be able to run permission analysis on the endpoints

### Fixed
- **Critical bug in `Get-AppActivityData`:**
  - Applications with high activity volumes (e.g., 19 million requests) would fail to gather activity data and return 0 results
  - Command now splits datetime ranges to handle large datasets reliably
  - Results are now complete and accurate regardless of activity volume

### Performance
- 2x faster execution with PSFramework runspace implementation while maintaining complete data accuracy

### Acknowledgments
Huge thanks to (FriedrichWeinmann) for his sparring and assistance on the PSFramework implementation.

## [0.1.2-preview] - 2025-11-26

### Changed
- Updated module manifest and build configuration
- Minor improvements to error handling and logging

### Fixed
- Resolved module loading issues in certain environments
- Improved reliability of permission analysis across different tenant configurations

## [0.1.1-preview] - 2025-11-26

### Added

- Initial public release of LeastPrivilegedMSGraph module
- **Core Cmdlets:**
  - `Get-AppRoleAssignment` - Retrieves all Enterprise Applications with their assigned Microsoft Graph permissions
  - `Get-AppActivityData` - Analyzes application activity from Azure Log Analytics workspace logs
  - `Get-AppThrottlingData` - Collects throttling statistics and error rates from Log Analytics
  - `Get-PermissionAnalysis` - Analyzes application permissions against actual API usage to identify least privileged permissions
  - `Export-PermissionAnalysisReport` - Generates comprehensive HTML reports with interactive visualizations
  - `Initialize-LogAnalyticsApi` - Registers the Log Analytics service for API queries
- **Permission Analysis Features:**
  - Automatic mapping of Graph API endpoints to least privileged permissions
  - Support for both v1.0 and beta Graph API endpoints
  - Detection of excess permissions granted to applications
  - Identification of unmatched API activities
  - Optimal permission recommendations based on actual usage
- **Reporting Capabilities:**
  - Interactive HTML reports with dark mode support
  - Filterable application grid with search functionality
  - Detailed permission breakdown and activity analysis
  - Throttling statistics and error rate visualization
  - Color-coded permission status indicators
- **Data Files:**
  - `permissions-v1.0.json` - Permission mappings for Microsoft Graph v1.0 API (1,885+ endpoints)
  - `permissions-beta.json` - Permission mappings for Microsoft Graph beta API (6,464+ endpoints)
  - `base.html` - HTML template for report generation with Tailwind CSS styling
- **GitHub Workflows:**
  - Automated Microsoft Graph permissions extraction workflow
  - Daily scheduled updates of permission mappings
  - Discord webhook notifications for permission updates
  - Support for manual workflow dispatch with test mode
- **Module Infrastructure:**
  - Built using Sampler framework for standardized module structure
  - PlatyPS integration for automatic documentation generation
  - Pester test framework support
  - Versioned module output with proper manifest configuration
  - Pipeline-enabled cmdlets for flexible data processing
- **Dependencies:**
  - Integration with EntraAuth module for authentication
  - Requires EntraAuth for Microsoft Graph and Log Analytics connectivity
- **Documentation:**
  - Comprehensive README with usage examples
  - Full pipeline example for end-to-end analysis
  - Individual cmdlet documentation
  - Data anonymization script for sharing reports

### Technical Details

- **Module Structure:**
  - Public functions: 6 user-facing cmdlets
  - Private functions: Internal helper functions for data processing
  - Data directory: JSON permission mappings and HTML templates
  - Build automation: Sampler-based build system with GitHub Actions
- **Permission Mapping:**
  - Extracted from official Microsoft Graph OpenAPI specifications
  - Regular expression-based endpoint matching
  - Support for path parameters and complex routes
  - Least privileged permission identification logic
- **Performance:**
  - Permission extraction using concurrent Node.js processing (limited by Azure Function App constraints)
  - Batch processing for Log Analytics queries
  - Efficient pipeline support for processing multiple applications
  - Optimized JSON file loading and caching

[Unreleased]: https://github.com/Mynster9361/Least_Privileged_MSGraph/compare/v0.1.2-preview...HEAD
[0.1.2-preview]: https://github.com/Mynster9361/Least_Privileged_MSGraph/compare/v0.1.1-preview...v0.1.2-preview
[0.1.1-preview]: https://github.com/Mynster9361/Least_Privileged_MSGraph/releases/tag/v0.1.1-preview
