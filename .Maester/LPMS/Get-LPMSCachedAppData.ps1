function Get-LPMSCachedAppData {
    <#
    .SYNOPSIS
        Fetches and caches the full LeastPrivilegedMSGraph permission analysis pipeline result.

    .DESCRIPTION
        Runs Get-LPMSAppRoleAssignment | Get-LPMSAppActivityData | Get-LPMSAppThrottlingData |
        Get-LPMSPermissionAnalysis once per Maester test run and caches the result in script scope.
        Subsequent calls within the same run return the cached data instantly.

        Configuration is resolved in priority order (first value found wins):
          1. Custom/maester-config.json  GlobalSettings (preferred for local runs)
          2. Environment variables        (preferred for CI/CD pipelines)
          3. Built-in defaults

        GlobalSettings keys (add to ./tests/Custom/maester-config.json):
            LPMSLogAnalyticsWorkspaceId  - Required. Log Analytics workspace GUID.
            LPMSDaysToQuery              - Optional. Days of history to analyse. Default: 30.
            LPMSMaxActivityEntries       - Optional. Max Log Analytics rows per SP. Default: 100000.
            LPMSThrottleLimit            - Optional. Parallel workers for activity fetch. Default: 10.
            LPMSOnlyPrivilegXAndOver     - Optional. Minimum privilege level to include in results. Default: 1.

        Environment variable fallbacks (CI/CD):
          LPMS_LOG_ANALYTICS_WORKSPACE_ID, LPMS_DAYS_TO_QUERY,
          LPMS_MAX_ACTIVITY_ENTRIES, LPMS_THROTTLE_LIMIT,
          LPMS_ONLY_PRIVILEGX_AND_OVER

    .OUTPUTS
        PSCustomObject[] | $null
        Returns the enriched application objects or $null on failure.
        On failure sets $script:_LPMSDataError with the exception.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    # Return cached result immediately on subsequent calls
    if ($script:_LPMSDataLoaded) {
        #return $script:_LPMSCachedData
    }

    $script:_LPMSDataLoaded = $true
    $script:_LPMSCachedData = $null
    $script:_LPMSDataError = $null

    try {
        # Resolve each setting: maester-config.json GlobalSettings → env var → default
        $wsId = if (Get-Command 'Get-MtMaesterConfigGlobalSetting' -ErrorAction SilentlyContinue) {
            Get-MtMaesterConfigGlobalSetting -SettingName 'LPMSLogAnalyticsWorkspaceId'
        }
        if ([string]::IsNullOrEmpty($wsId)) {
            $wsId = $env:LPMS_LOG_ANALYTICS_WORKSPACE_ID
        }

        $days = if (Get-Command 'Get-MtMaesterConfigGlobalSetting' -ErrorAction SilentlyContinue) {
            Get-MtMaesterConfigGlobalSetting -SettingName 'LPMSDaysToQuery'
        }
        if (-not $days) {
            $days = $env:LPMS_DAYS_TO_QUERY
        }
        $days = if ($days) {
            [int]$days
        }
        else {
            30
        }

        $maxEntries = if (Get-Command 'Get-MtMaesterConfigGlobalSetting' -ErrorAction SilentlyContinue) {
            Get-MtMaesterConfigGlobalSetting -SettingName 'LPMSMaxActivityEntries'
        }
        if (-not $maxEntries) {
            $maxEntries = $env:LPMS_MAX_ACTIVITY_ENTRIES
        }
        $maxEntries = if ($maxEntries) {
            [int]$maxEntries
        }
        else {
            100000
        }

        $throttle = if (Get-Command 'Get-MtMaesterConfigGlobalSetting' -ErrorAction SilentlyContinue) {
            Get-MtMaesterConfigGlobalSetting -SettingName 'LPMSThrottleLimit'
        }
        if (-not $throttle) {
            $throttle = $env:LPMS_THROTTLE_LIMIT
        }
        $throttle = if ($throttle) {
            [int]$throttle
        }
        else {
            10
        }

        $privLevel = if (Get-Command 'Get-MtMaesterConfigGlobalSetting' -ErrorAction SilentlyContinue) {
            Get-MtMaesterConfigGlobalSetting -SettingName 'LPMSOnlyPrivilegXAndOver'
        }
        if (-not $privLevel) {
            $privLevel = $env:LPMS_ONLY_PRIVILEGX_AND_OVER
        }
        $privLevel = if ($privLevel) {
            [int]$privLevel
        }
        else {
            1
        }

        # Ensure the Log Analytics OAuth scope is cached in the Az token store.
        # Connect-AzAccount -AuthScope is a no-op when the token is already cached;
        # it only prompts if Conditional Access requires a one-time MFA step-up for
        # the https://api.loganalytics.io resource. Skip this block when Az.Accounts
        # is not available (e.g. pure service-principal environments).
        if (Get-Command 'Connect-AzAccount' -ErrorAction SilentlyContinue) {
            Connect-AzAccount -AuthScope 'https://api.loganalytics.io' -ErrorAction SilentlyContinue | Out-Null
        }

        Connect-EntraService -Service "LogAnalytics", "GraphBeta" -AsAzAccount
        $script:_LPMSCachedData = Get-LPMSAppRoleAssignment |
            Get-LPMSAppActivityData   -WorkspaceId $wsId -Days $days -MaxActivityEntries $maxEntries -ThrottleLimit $throttle |
                Get-LPMSAppThrottlingData -WorkspaceId $wsId -Days $days |
                    Get-LPMSPermissionAnalysis | Where-Object { $_.CurrentPermissions.PrivilegeLevel -ge $privLevel }

        return $script:_LPMSCachedData
    }
    catch {
        $script:_LPMSDataError = $_
        return $null
    }
}
