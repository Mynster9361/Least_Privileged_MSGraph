function Get-LPMSExcessPermissionsInstance {
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
            Title = "$($app.PrincipalName): excess permissions check"
            Data  = $app
        }
    }
}

function Test-LPMSExcessPermissions {
    <#
    .SYNOPSIS
        Checks whether a service principal holds permissions beyond what its actual API activity requires.

    .DESCRIPTION
        Uses the LeastPrivilegedMSGraph permission analysis of one service principal and fails when
        ExcessPermissions.Count > 0, meaning it has been granted permissions it did not exercise
        during the analysis window.

        Returns $true  when the service principal has no excess permissions.
        Returns $false when the service principal carries excess permissions.

    .LINK
        https://github.com/Mynster9361/LeastPrivilegedMSGraph
    #>
    [MaesterTest(
        Id                 = 'LPMS.001',
        Title              = 'Service principals hold only the Microsoft Graph permissions their activity requires',
        Product            = 'entra',
        Feature            = 'app-consent',
        Area               = 'applications',
        ResourceType       = 'ServicePrincipal',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Medium',
        Mitre              = ('T1078.004', 'T1528'),
        Control            = 'nist-800-53-r5:AC-6',
        Service            = 'Azure',
        Permission         = 'Application.Read.All',
        InstanceSource     = 'Get-LPMSExcessPermissionsInstance',
        Author             = 'Mynster9361',
        HelpUrl            = 'https://mynster-it.dk/docs/modules/leastprivilegedmsgraph'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The service principal to check, from Get-LPMSExcessPermissionsInstance.
        $Instance
    )

    $app = $Instance.Data
    $testResult = ($app.ExcessPermissions.Count -eq 0)
    $portalLink = 'https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Permissions/objectId/{0}'

    if ($testResult) {
        $resultMarkdown = "Well done. **$($app.PrincipalName)** has no excess permissions and operates under the principle of least privilege."
    } else {
        $resultMarkdown = "**[$($app.PrincipalName)]($($portalLink -f $app.PrincipalId))** holds **$($app.ExcessPermissions.Count)** permission(s) that were not exercised during the analysis window.`n`n"
        $resultMarkdown += "Removing these excess permissions reduces the tenant's attack surface.`n`n"
        $resultMarkdown += "| Permission | Scope |`n"
        $resultMarkdown += "| --- | --- |`n"
        foreach ($perm in ($app.ExcessPermissions | Sort-Object Permission, ScopeType)) {
            $resultMarkdown += "| $($perm.Permission) | $($perm.ScopeType) |`n"
        }

        if ($app.MatchedAllActivity -eq $false) {
            $resultMarkdown += "`n`n"
            $resultMarkdown += "**Additionally, this application has $(@($app.UnmatchedActivities).Count) unmatched activity endpoint(s) that could not be resolved to a known permission. The least-privilege analysis for this application is incomplete. Manual review is required to confirm its permission posture.**`n`n"
            $resultMarkdown += "| Unmatched Endpoints |`n"
            $resultMarkdown += "| --- |`n"
            foreach ($activity in ($app.UnmatchedActivities | Select-Object -First 5)) {
                $resultMarkdown += "| ``$($activity.Method) $($activity.Path)`` |`n"
            }
        }

        if ($app.OptimalPermissions.Count -gt 0) {
            $resultMarkdown += "`n`n"
            $resultMarkdown += "The following permission table is the OptimalPermissions result for this application, which represents the minimum set of permissions required to support its recorded activity. Compare this table to the assigned permissions above to identify which permissions can be safely removed.`n`n"
            $resultMarkdown += "| Permission | Scope |`n"
            $resultMarkdown += "| --- | --- |`n"
            foreach ($perm in ($app.OptimalPermissions | Sort-Object Permission, ScopeType)) {
                $resultMarkdown += "| $($perm.Permission) | $($perm.ScopeType) |`n"
            }
        }
    }

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
