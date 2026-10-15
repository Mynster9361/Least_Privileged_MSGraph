function Get-LPMSUnmatchedActivitiesInstance {
    <#
    .SYNOPSIS
        Returns one instance per service principal with recorded activity, where endpoint matching is meaningful.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    . (Join-Path $PSScriptRoot 'helpers/Get-LPMSCachedAppData.ps1')
    $data = Get-LPMSCachedAppData

    $apps = $data.Apps | Where-Object {
        $null -ne $_.Activity -and
        @($_.Activity).Count -gt 0 -and
        $null -ne $_.MatchedAllActivity
    }
    foreach ($app in $apps) {
        [PSCustomObject]@{
            Id    = $app.PrincipalId
            Title = "$($app.PrincipalName): API activity endpoint matching"
            Data  = $app
        }
    }
}

function Test-LPMSUnmatchedActivities {
    <#
    .SYNOPSIS
        Checks whether a service principal has Graph API activity that could not be matched
        to a known endpoint for least-privilege analysis.

    .DESCRIPTION
        A service principal with unmatched activities (MatchedAllActivity = $false) has made
        Graph API calls whose endpoints could not be resolved to a minimum-required permission.
        This means its ExcessPermissions and OptimalPermissions results are incomplete: the
        tool cannot confidently recommend permission removal for that application.

        The result is reported with the Investigate status because unmatched activities are not
        a direct security failure but require manual review.

        Returns $true  when all activity of the service principal was matched.
        Returns $false when it has unmatched activity (flagged as Investigate).

    .LINK
        https://github.com/Mynster9361/LeastPrivilegedMSGraph
    #>
    [MaesterTest(
        Id                 = 'LPMS.002',
        Title              = 'All Microsoft Graph activity of service principals matches a known endpoint',
        Product            = 'entra',
        Feature            = 'app-consent',
        Area               = 'applications',
        ResourceType       = 'ServicePrincipal',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'Medium',
        Mitre              = 'None',
        Service            = 'Azure',
        Permission         = 'Application.Read.All',
        InstanceSource     = 'Get-LPMSUnmatchedActivitiesInstance',
        Author             = 'Mynster9361',
        HelpUrl            = 'https://mynster-it.dk/docs/modules/leastprivilegedmsgraph'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The service principal to check, from Get-LPMSUnmatchedActivitiesInstance.
        $Instance
    )

    $app = $Instance.Data
    $testResult = ($app.MatchedAllActivity -ne $false)
    $portalLink = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Permissions/objectId/{0}'

    if ($testResult) {
        $resultMarkdown = "Well done. All Graph API activity for **$($app.PrincipalName)** was matched to a known endpoint. The permission analysis is complete."
    } else {
        $unmatchedCount = @($app.UnmatchedActivities | Where-Object { $null -ne $_ }).Count
        $unmatchedUris = if ($unmatchedCount -gt 0) {
            ($app.UnmatchedActivities | Select-Object -First 5 | ForEach-Object { "``$($_.Method) $($_.Path)``" }) -join '<br/>'
        } else {
            '_Unknown_'
        }
        $resultMarkdown = "**[$($app.PrincipalName)]($($portalLink -f $app.PrincipalId))** has Graph API activity that could not be matched to a known endpoint.`n`n"
        $resultMarkdown += "The least-privilege analysis for this application may be incomplete. Manual review is required to confirm its permission posture.`n`n"
        $resultMarkdown += "| Unmatched Endpoints |`n"
        $resultMarkdown += "| --- |`n"
        $resultMarkdown += "| $unmatchedUris |`n"
    }

    Add-MtTestResultDetail -Result $resultMarkdown -Investigate:(-not $testResult)
    return $testResult
}
