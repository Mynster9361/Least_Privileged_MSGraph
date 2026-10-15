function Get-LPMSNoActivityInstance {
    <#
    .SYNOPSIS
        Returns one instance per service principal that has at least one Microsoft Graph permission assigned.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    . (Join-Path $PSScriptRoot 'helpers/Get-LPMSCachedAppData.ps1')
    $data = Get-LPMSCachedAppData

    foreach ($app in ($data.Apps | Where-Object { $_.AppRoleCount -gt 0 })) {
        [PSCustomObject]@{
            Id    = $app.PrincipalId
            Title = "$($app.PrincipalName): permissions with no recorded activity"
            Data  = [PSCustomObject]@{ App = $app; Days = $data.Settings.Days }
        }
    }
}

function Test-LPMSNoActivity {
    <#
    .SYNOPSIS
        Checks whether a service principal has been granted Graph API permissions but recorded
        no API activity during the analysis window.

    .DESCRIPTION
        A service principal that holds permissions but made zero Graph API calls during the
        analysis period is a candidate for decommissioning or permission removal.

        Results are reported with the Investigate status because zero activity does not
        automatically mean the application is unused: it may simply be outside its active period.

        Only service principals with at least one assigned permission (AppRoleCount > 0) are evaluated.

        Returns $true  when the service principal recorded at least one API call.
        Returns $false when it recorded no activity.

    .LINK
        https://github.com/Mynster9361/LeastPrivilegedMSGraph
    #>
    [MaesterTest(
        Id                 = 'LPMS.004',
        Title              = 'Service principals with Microsoft Graph permissions show activity in the analysis window',
        Product            = 'entra',
        Feature            = 'applications',
        Area               = 'applications',
        ResourceType       = 'ServicePrincipal',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = ('T1078.004', 'T1098.001'),
        Control            = 'nist-800-53-r5:AC-2(3)',
        Service            = 'Azure',
        Permission         = 'Application.Read.All',
        InstanceSource     = 'Get-LPMSNoActivityInstance',
        Author             = 'Mynster9361',
        HelpUrl            = 'https://mynster-it.dk/docs/modules/leastprivilegedmsgraph'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The service principal to check, from Get-LPMSNoActivityInstance.
        $Instance
    )

    $app = $Instance.Data.App
    $days = $Instance.Data.Days
    $testResult = ($null -ne $app.Activity -and @($app.Activity).Count -gt 0)

    if ($testResult) {
        $resultMarkdown = "Well done. **$($app.PrincipalName)** recorded at least one Graph API call during the last $days days."
    } else {
        $portalLink = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Permissions/objectId/{0}'
        $permCount = $app.AppRoleCount
        $permTypes = ($app.AppRoles | Select-Object -ExpandProperty PermissionType -Unique) -join ', '
        $resultMarkdown = "**[$($app.PrincipalName)]($($portalLink -f $app.PrincipalId))** has **$permCount** assigned permission(s) but **no recorded activity** in the last $days days.`n`n"
        $resultMarkdown += "This application may be stale, unused, or operating outside the analysis window. Review it and consider revoking permissions or decommissioning the registration if it is no longer needed.`n`n"
        $resultMarkdown += "| Assigned Permissions | Permission Types |`n"
        $resultMarkdown += "| --- | --- |`n"
        $resultMarkdown += "| $permCount | $permTypes |`n"
    }

    Add-MtTestResultDetail -Result $resultMarkdown -Investigate:(-not $testResult)
    return $testResult
}
