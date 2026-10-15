function Get-LPMSCachedAppData {
    <#
    .SYNOPSIS
        Fetches and caches the full LeastPrivilegedMSGraph permission analysis pipeline result.

    .DESCRIPTION
        Runs Get-LPMSAppRoleAssignment | Get-LPMSAppActivityData | Get-LPMSAppThrottlingData |
        Get-LPMSPermissionAnalysis and caches the result so the four LPMS checks share one pipeline run.

        Maester 3.0 loads every custom test file into its own private module, so script scope is not
        shared between the checks. The result is therefore cached in the global scope, keyed by the
        settings and the Azure tenant, and reused for LPMSCacheMinutes (default 60). Remove the
        variable to force a refresh:
            Remove-Variable -Name LPMSMaesterCache -Scope Global

        This file is not a test: it is dot-sourced by the instance source of each Test.LPMS.*.ps1.

        Configuration is resolved in priority order (first value found wins):
          1. maester-config.json GlobalSettings (read through Get-MtSetting)
          2. Environment variables (preferred for CI/CD pipelines)
          3. Built-in defaults

        GlobalSettings keys:
            LPMSLogAnalyticsWorkspaceId  - Required. Log Analytics workspace GUID.
            LPMSDaysToQuery              - Optional. Days of history to analyse. Default: 30.
            LPMSMaxActivityEntries       - Optional. Max Log Analytics rows per SP. Default: 100000.
            LPMSThrottleLimit            - Optional. Parallel workers for activity fetch. Default: 10.
            LPMSOnlyPrivilegXAndOver     - Optional. Minimum privilege level to include in results. Default: 1.
            LPMSCacheMinutes             - Optional. Minutes the pipeline result is reused. Default: 60.

        Environment variable fallbacks (CI/CD):
          LPMS_LOG_ANALYTICS_WORKSPACE_ID, LPMS_DAYS_TO_QUERY,
          LPMS_MAX_ACTIVITY_ENTRIES, LPMS_THROTTLE_LIMIT,
          LPMS_ONLY_PRIVILEGX_AND_OVER, LPMS_CACHE_MINUTES

    .OUTPUTS
        PSCustomObject with Settings and Apps. Throws when the pipeline cannot run, so Maester reports
        the family as an Error row with the message.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $resolve = {
        param($settingName, $envName, $default)
        $value = Get-MtSetting -Name $settingName
        if ([string]::IsNullOrEmpty($value)) {
            $value = [System.Environment]::GetEnvironmentVariable($envName)
        }
        if ([string]::IsNullOrEmpty($value)) {
            $value = $default
        }
        $value
    }

    $settings = [PSCustomObject]@{
        WorkspaceId  = [string](& $resolve 'LPMSLogAnalyticsWorkspaceId' 'LPMS_LOG_ANALYTICS_WORKSPACE_ID' $null)
        Days         = [int](& $resolve 'LPMSDaysToQuery' 'LPMS_DAYS_TO_QUERY' 30)
        MaxEntries   = [int](& $resolve 'LPMSMaxActivityEntries' 'LPMS_MAX_ACTIVITY_ENTRIES' 100000)
        Throttle     = [int](& $resolve 'LPMSThrottleLimit' 'LPMS_THROTTLE_LIMIT' 10)
        PrivLevel    = [int](& $resolve 'LPMSOnlyPrivilegXAndOver' 'LPMS_ONLY_PRIVILEGX_AND_OVER' 1)
        CacheMinutes = [int](& $resolve 'LPMSCacheMinutes' 'LPMS_CACHE_MINUTES' 60)
    }

    if ([string]::IsNullOrEmpty($settings.WorkspaceId)) {
        throw 'The Log Analytics workspace ID is not configured. Set GlobalSettings.LPMSLogAnalyticsWorkspaceId in maester-config.json or the LPMS_LOG_ANALYTICS_WORKSPACE_ID environment variable.'
    }

    $tenantId = (Get-AzContext).Tenant.Id
    $key = '{0}|{1}|{2}|{3}|{4}' -f $tenantId, $settings.WorkspaceId, $settings.Days, $settings.MaxEntries, $settings.PrivLevel
    $cache = Get-Variable -Name LPMSMaesterCache -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    if ($cache -and $cache.Key -eq $key -and $cache.Loaded -gt (Get-Date).AddMinutes(-$settings.CacheMinutes)) {
        return [PSCustomObject]@{ Settings = $settings; Apps = $cache.Apps }
    }

    Connect-EntraService -Service 'LogAnalytics', 'GraphBeta' -AsAzAccount
    $apps = @(
        Get-LPMSAppRoleAssignment |
            Get-LPMSAppActivityData -WorkspaceId $settings.WorkspaceId -Days $settings.Days -MaxActivityEntries $settings.MaxEntries -ThrottleLimit $settings.Throttle |
                Get-LPMSAppThrottlingData -WorkspaceId $settings.WorkspaceId -Days $settings.Days |
                    Get-LPMSPermissionAnalysis |
                        Where-Object { $_.CurrentPermissions.PrivilegeLevel -ge $settings.PrivLevel }
    )

    Set-Variable -Name LPMSMaesterCache -Scope Global -Value ([PSCustomObject]@{
            Key    = $key
            Loaded = Get-Date
            Apps   = $apps
        })

    [PSCustomObject]@{ Settings = $settings; Apps = $apps }
}
