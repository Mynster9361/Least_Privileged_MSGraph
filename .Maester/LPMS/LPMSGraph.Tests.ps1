#Requires -Module LeastPrivilegedMSGraph
<#
.SYNOPSIS
    Maester custom tests for the LeastPrivilegedMSGraph module.

.DESCRIPTION
    This test file verifies that service principals in the tenant follow the principle of
    least privilege and are behaving as expected, using the LeastPrivilegedMSGraph module
    to perform permission analysis against actual Log Analytics activity data.

    Each check produces one Pester test per service principal so that individual applications
    appear as separate Pass / Fail / Investigate rows in the Maester report, rather than a
    single aggregate result.

.PREREQUISITES
    1. The LeastPrivilegedMSGraph module is imported:
           Import-Module LeastPrivilegedMSGraph
    2. Log Analytics scope is cached in the Az token store:
           Connect-AzAccount -AuthScope 'https://api.loganalytics.io'
    3. Graph and Log Analytics connections are established, for example via Connect-Maester
       and the module's own initialization:
           Connect-EntraService -Service 'LogAnalytics','GraphBeta' -AsAzAccount
    4. The workspace ID is configured in Custom/maester-config.json GlobalSettings:
           { "GlobalSettings": { "LPMSLogAnalyticsWorkspaceId": "<guid>" } }
       Or via environment variable:
           $env:LPMS_LOG_ANALYTICS_WORKSPACE_ID = '<guid>'

.NOTES
    Days recommendation  : 30 days captures a full monthly API activity cycle.
    MaxActivityEntries   : 100 000 (default) suits most tenants.
#>

BeforeDiscovery {
    # Dot-source the data helper so it is available during discovery.
    # Helper function files are dot-sourced again in BeforeAll for test execution.
    . "$PSScriptRoot/Get-LPMSCachedAppData.ps1"

    # Fetch the full pipeline result once. Subsequent calls return the cached copy.
    $allApps = try {
        Get-LPMSCachedAppData
    }
    catch {
        $null
    }

    $portalBase = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Permissions/objectId/{0}'

    if ($allApps) {
        # LPMS.001 — one test per SP that has at least one permission assigned
        $excessCases = @(
            $allApps | Where-Object { $_.AppRoleCount -gt 0 } |
                ForEach-Object { @{ App = $_; PrincipalName = $_.PrincipalName; PrincipalId = ($_.PrincipalId.Substring(0, 16)) } }
        )

        # LPMS.002 — one test per SP that has recorded activity (matching is only meaningful
        #            when activity exists)
        $unmatchedCases = @(
            $allApps | Where-Object {
                $null -ne $_.Activity -and
                @($_.Activity).Count -gt 0 -and
                $null -ne $_.MatchedAllActivity
            } |
                ForEach-Object { @{ App = $_; PrincipalName = $_.PrincipalName; PrincipalId = ($_.PrincipalId.Substring(0, 16)) } }
        )

        # LPMS.003 — one test per SP that has throttling statistics
        $throttlingCases = @(
            $allApps | Where-Object { $null -ne $_.ThrottlingStats } |
                ForEach-Object { @{ App = $_; PrincipalName = $_.PrincipalName; PrincipalId = ($_.PrincipalId.Substring(0, 16)) } }
        )

        # LPMS.004 — one test per SP that has at least one permission assigned
        $noActivityCases = @(
            $allApps | Where-Object { $_.AppRoleCount -gt 0 } |
                ForEach-Object { @{ App = $_; PrincipalName = $_.PrincipalName; PrincipalId = ($_.PrincipalId.Substring(0, 16)) } }
        )
    }
    else {
        # Pipeline failed — insert a single sentinel per check so a Skip/Error result is
        # shown in the report rather than the check silently disappearing.
        $sentinel = @{ App = $null; PrincipalName = '[Pipeline Error]' }
        $excessCases = @($sentinel)
        $unmatchedCases = @($sentinel)
        $throttlingCases = @($sentinel)
        $noActivityCases = @($sentinel)
    }
}

BeforeAll {
    . "$PSScriptRoot/Get-LPMSCachedAppData.ps1"
    . "$PSScriptRoot/Test-LPMSExcessPermissions.ps1"
    . "$PSScriptRoot/Test-LPMSUnmatchedActivities.ps1"
    . "$PSScriptRoot/Test-LPMSCriticalThrottling.ps1"
    . "$PSScriptRoot/Test-LPMSNoActivity.ps1"
}

Describe "LeastPrivilegedMSGraph" -Tag "Maester", "Azure" {

    It "LPMS.001.<PrincipalId>: <PrincipalName> — excess permissions check" `
        -Tag "LPMS.001", "Severity:High" `
        -ForEach $excessCases {

        $result = Test-LPMSExcessPermissions -App $App

        if ($null -ne $result) {
            $result | Should -Be $true -Because "service principals should operate under the principle of least privilege and hold only permissions that their actual API activity requires"
        }
    }

    It "LPMS.002.<PrincipalId>: <PrincipalName> — API activity endpoint matching" `
        -Tag "LPMS.002", "Severity:Medium" `
        -ForEach $unmatchedCases {

        $result = Test-LPMSUnmatchedActivities -App $App

        if ($null -ne $result) {
            $result | Should -Be $true -Because "unmatched activity means the permission analysis is incomplete and the true minimum permission set cannot be determined"
        }
    }

    It "LPMS.003.<PrincipalId>: <PrincipalName> — Graph API throttling severity" `
        -Tag "LPMS.003", "Severity:Medium" `
        -ForEach $throttlingCases {

        $result = Test-LPMSCriticalThrottling -App $App

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Warning or Critical throttling indicates API misuse patterns such as polling loops or missing retry/batching/backoff logic"
        }
    }

    It "LPMS.004.<PrincipalId>: <PrincipalName> — permissions with no recorded activity" `
        -Tag "LPMS.004", "Severity:Medium" `
        -ForEach $noActivityCases {

        $result = Test-LPMSNoActivity -App $App

        if ($null -ne $result) {
            $result | Should -Be $true -Because "permissioned service principals with no activity may be stale and represent an unnecessary attack surface"
        }
    }
}
