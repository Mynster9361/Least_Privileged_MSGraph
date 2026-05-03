# Changelog for LeastPrivilegedMSGraph

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]

### Added
- Added `Get-PermissionRiskLevel` private function that replaces the previous single-factor schema lookup with a multi-factor risk analysis:
  - **Critical override list** – curated patterns for permissions that can compromise tenant security (e.g. `RoleManagement.*`, `AppRoleAssignment.ReadWrite.All`, `Application.ReadWrite.All`)
  - **High override list** – permissions with significant data exposure or write capability (e.g. `Mail.Send`, `AuditLog.Read.All`, `BitlockerKey.Read.All`)
  - **Schema baseline** – Microsoft's official `privilegeLevel` from `permissions.json` when no override applies
  - **Scope type adjustment** – Application-scope permissions receive a +1 risk bump (capped at 4) since they are persistent, have no user-context ceiling and carry full tenant blast radius
- Added `RiskLabel` property (`Low`, `Medium`, `High`, `Critical`) to all permission objects output by `Get-LPMSPermissionAnalysis`
- Added colored risk badges (`Critical`, `High`, `Medium`, `Low`) to individual permissions in the HTML report detail panel (Current, Excess, Missing, and Optimal permission sections)
- Added descriptive labels to the privilege level column in the HTML report table (`L4 - Critical`, `L3 - High`, `L2 - Medium`, `L1 - Low`)
- Added unit tests for `Get-PermissionRiskLevel` covering critical/high overrides, name-pattern inference, schema integration, scope bumping, and output structure
- Added `source/report/` — a Vite + React + TypeScript project that produces the HTML report template as a single self-contained file (no CDN dependencies). Run `npm run build` in `source/report/` to rebuild the template at `source/data/base.html`. Features: TanStack Table (replacing jQuery DataTables), PostCSS Tailwind (replacing CDN browser build), `vite-plugin-singlefile` for full asset inlining

## [3.0.0] - 2026-04-03

### Changed
- BREAKING CHANGE: Renamed Export-PermissionAnalysisReport to Export-LPMPermissionAnalysisReport to create a more consistent naming convention across the module.
- BREAKING CHANGE: Renamed Get-AppActivityData to Get-LPMSAppActivityData to create a more consistent naming convention across the module.
- BREAKING CHANGE: Renamed Get-AppRoleAssignment to Get-LPMSAppRoleAssignment to create a more consistent naming convention across the module.
- BREAKING CHANGE: Renamed Get-AppThrottlingData to Get-LPMSAppThrottlingData to create a more consistent naming convention across the module.
- BREAKING CHANGE: Renamed Get-PermissionAnalysis to Get-LPMSPermissionAnalysis to create a more consistent naming convention across the module.
- BREAKING CHANGE: Renamed Initialize-LogAnalyticsApi to Initialize-LPMSLogAnalyticsApi to create a more consistent naming convention across the module.

### Acknowledgments
Constantin Hager - Thanks for taking the initiative to uniform the module to follow a consistent naming convention

## [2.0.0] - 2026-02-24

### Added
- Delegated permissions is now included in the report to give better visibility into your apps and its permissions
- Dependencies to 'MSGraphPermissions', 'EntraAuth.Graph' which lets us get better visibility to the correct permission scopes for each url included EntraAuth.Graph for improved performance
- Improved limitation in activity gathering so you are able to both set a throtle limit on this along with specifying how many activities you would like to base your permission scoping upon
- Report Improvements as listed below:
- - Added permission scopes for each permission to difrenciate between application and delegated scopes
- - Ability to expand the optimal permissions to see which endpoints this permission will cover
- - Improved UI in regards to the vertical scope of the page and moved a button to the left
- - Added built in filters in the top overview to understand and apply filters faster
- - Added tenant information to the report
- - Added additional data to the csv export from the report
- - More filtering options

### Removed
- No longer supports powershell 5.1 minimum powershell version is now 7.4
- Permission complexity from this module and seperated into its own module 'MSGraphPermissions' with improved permission lookup (More endpoints and more accurate permission scoping)
- Activity gathering using PSFrameworks runspaces replaced with forech -parralel from powershell 7

### Fixed
- An issue in gathering activity data caused by runspaces crashing while attempting to pull data from the endpoints
- Throttling from the log analytics API causing some data to not be returned

### Acknowledgments
Jake Hildreth - Thanks for the sparring and feedback
Friedrich Weinmann - Thanks for the sparring and feedback


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
