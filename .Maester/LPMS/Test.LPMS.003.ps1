function Get-LPMSCriticalThrottlingInstance {
    <#
    .SYNOPSIS
        Returns one instance per service principal that has throttling statistics.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    . (Join-Path $PSScriptRoot 'helpers/Get-LPMSCachedAppData.ps1')
    $data = Get-LPMSCachedAppData

    foreach ($app in ($data.Apps | Where-Object { $null -ne $_.ThrottlingStats })) {
        [PSCustomObject]@{
            Id    = $app.PrincipalId
            Title = "$($app.PrincipalName): Graph API throttling severity"
            Data  = $app
        }
    }
}

function Test-LPMSCriticalThrottling {
    <#
    .SYNOPSIS
        Checks whether a service principal is experiencing severe Microsoft Graph API throttling.

    .DESCRIPTION
        Evaluates the ThrottlingStats.ThrottlingSeverity value of the service principal and flags
        it at severity level 3 (Warning: 10-25% throttle rate) or 4 (Critical: >25% throttle rate).

        Throttling severity scale used by LeastPrivilegedMSGraph:
          0 - Normal      : No activity or < 1% throttle rate
          1 - Minimal     : 1-5% throttle rate
          2 - Low         : 5-10% throttle rate
          3 - Warning     : 10-25% throttle rate, optimisation recommended
          4 - Critical    : >25% throttle rate, immediate action required

        Results are reported with the Investigate status so that operators can confirm whether
        the throttling is expected (e.g., a scheduled bulk job) or a sign of misbehaviour.

        Returns $true  when the service principal is below severity 3.
        Returns $false when it has a Warning or Critical throttle rate.

    .LINK
        https://github.com/Mynster9361/LeastPrivilegedMSGraph
    #>
    [MaesterTest(
        Id                 = 'LPMS.003',
        Title              = 'Service principals are not throttled at Warning or Critical level by Microsoft Graph',
        Product            = 'entra',
        Feature            = 'applications',
        Area               = 'applications',
        ResourceType       = 'ServicePrincipal',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'High',
        Mitre              = 'None',
        Service            = 'Azure',
        Permission         = 'Application.Read.All',
        InstanceSource     = 'Get-LPMSCriticalThrottlingInstance',
        Author             = 'Mynster9361',
        HelpUrl            = 'https://mynster-it.dk/docs/modules/leastprivilegedmsgraph'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The service principal to check, from Get-LPMSCriticalThrottlingInstance.
        $Instance
    )

    $app = $Instance.Data
    # Severity 3 = Warning (10-25%), severity 4 = Critical (>25%)
    $testResult = ($app.ThrottlingStats.ThrottlingSeverity -lt 3)
    $portalLink = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/{0}'
    $severityLabels = @{ 3 = '⚠️ Warning'; 4 = '🔴 Critical' }

    if ($testResult) {
        $resultMarkdown = "Well done. **$($app.PrincipalName)** is not experiencing Warning or Critical Graph API throttling."
    } else {
        $stats = $app.ThrottlingStats
        $severityLabel = $severityLabels[[int]$stats.ThrottlingSeverity]
        $lastSeen = if ($stats.LastOccurrence) { ([datetime]$stats.LastOccurrence).ToString('yyyy-MM-dd') } else { '_unknown_' }
        $throttleRate = "$([math]::Round($stats.ThrottleRate, 1))%"
        $resultMarkdown = "**[$($app.PrincipalName)]($($portalLink -f $app.PrincipalId))** is experiencing significant Graph API throttling.`n`n"
        $resultMarkdown += "Please review whether the throttling is expected behaviour or indicates a defect such as a polling loop or missing retry/batching logic.`n`n"
        $resultMarkdown += "| Throttle Rate | Severity | Total Requests | 429 Errors | Last Seen |`n"
        $resultMarkdown += "| --- | --- | --- | --- | --- |`n"
        $resultMarkdown += "| $throttleRate | $severityLabel | $($stats.TotalRequests) | $($stats.Total429Errors) | $lastSeen |`n"
    }

    Add-MtTestResultDetail -Result $resultMarkdown -Investigate:(-not $testResult)
    return $testResult
}
