function Test-LPMSCriticalThrottling {
    <#
    .SYNOPSIS
        Checks whether any service principal is experiencing severe Microsoft Graph API throttling.

    .DESCRIPTION
        Evaluates the ThrottlingStats.ThrottlingSeverity value for each service principal and flags
        those at severity level 3 (Warning: 10-25% throttle rate) or 4 (Critical: >25% throttle rate).

        Throttling severity scale used by LeastPrivilegedMSGraph:
          0 - Normal      : No activity or < 1% throttle rate
          1 - Minimal     : 1-5% throttle rate
          2 - Low         : 5-10% throttle rate
          3 - Warning     : 10-25% throttle rate — optimisation recommended
          4 - Critical    : >25% throttle rate — immediate action required

        High throttle rates indicate that an application is making more API calls than the
        Microsoft Graph service can accept, which degrades user-facing features and may indicate
        missing retry logic, missing batching, or an unintended polling loop.

        Results are reported with the Investigate status so that operators can confirm whether
        the throttling is expected (e.g., a scheduled bulk job) or a sign of misbehaviour.

        Returns $true  when no service principals are at severity 3 or above.
        Returns $false when one or more service principals have a Warning or Critical throttle rate.
        Returns $null  when the check could not run.

    .EXAMPLE
        Test-LPMSCriticalThrottling

    .LINK
        https://github.com/Mynster9361/LeastPrivilegedMSGraph
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        $App
    )

    if ($null -eq $App) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Application data pipeline failed. Check the BeforeAll block logs for details."
        return $null
    }

    try {
        # Severity 3 = Warning (10-25%), severity 4 = Critical (>25%)
        $testResult = ($null -eq $App.ThrottlingStats -or $App.ThrottlingStats.ThrottlingSeverity -lt 3)
        $portalLink = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/{0}"
        $severityLabels = @{ 3 = '⚠️ Warning'; 4 = '🔴 Critical' }

        if ($testResult) {
            $resultMarkdown = "Well done! **$($App.PrincipalName)** is not experiencing Warning or Critical Graph API throttling."
        }
        else {
            $stats = $App.ThrottlingStats
            $severityLabel = $severityLabels[$stats.ThrottlingSeverity]
            $lastSeen = if ($stats.LastOccurrence) { ([datetime]$stats.LastOccurrence).ToString('yyyy-MM-dd') } else { '_unknown_' }
            $throttleRate = "$([math]::Round($stats.ThrottleRate, 1))%"
            $resultMarkdown = "**[$($App.PrincipalName)]($($portalLink -f $App.PrincipalId))** is experiencing significant Graph API throttling.`n`n"
            $resultMarkdown += "Please review whether the throttling is expected behaviour or indicates a defect such as a polling loop or missing retry/batching logic.`n`n"
            $resultMarkdown += "| Throttle Rate | Severity | Total Requests | 429 Errors | Last Seen |`n"
            $resultMarkdown += "| --- | --- | --- | --- | --- |`n"
            $resultMarkdown += "| $throttleRate | $severityLabel | $($stats.TotalRequests) | $($stats.Total429Errors) | $lastSeen |`n"
        }

        Add-MtTestResultDetail -Result $resultMarkdown -Investigate:(-not $testResult)
        return $testResult
    }
    catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
