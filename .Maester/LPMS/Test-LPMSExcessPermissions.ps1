function Test-LPMSExcessPermissions {
    <#
    .SYNOPSIS
        Checks whether any service principal holds permissions beyond what its actual API activity requires.

    .DESCRIPTION
        Retrieves the full LeastPrivilegedMSGraph permission analysis and identifies service principals
        where ExcessPermissions.Count > 0, meaning they have been granted permissions they did not
        exercise during the analysis window.

        Returns $true  when no over-privileged service principals are found.
        Returns $false when one or more service principals carry excess permissions.
        Returns $null  when the check could not run (module not loaded, workspace not configured, etc.).

    .EXAMPLE
        Test-LPMSExcessPermissions

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
        $testResult = ($App.ExcessPermissions.Count -eq 0)
        $portalLink = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Permissions/objectId/{0}"

        if ($testResult) {
            $resultMarkdown = "Well done! **$($App.PrincipalName)** has no excess permissions and operates under the principle of least privilege."
        } else {
            $resultMarkdown = "**[$($App.PrincipalName)]($($portalLink -f $App.PrincipalId))** holds **$($App.ExcessPermissions.Count)** permission(s) that were not exercised during the analysis window.`n`n"
            $resultMarkdown += "Removing these excess permissions reduces the tenant's attack surface.`n`n"
            $resultMarkdown += "| Permission | Scope |`n"
            $resultMarkdown += "| --- | --- |`n"
            foreach ($perm in ($App.ExcessPermissions | Sort-Object Permission, ScopeType)) {
                $resultMarkdown += "| $($perm.Permission) | $($perm.ScopeType) |`n"
            }

            if ($App.MatchedAllActivity -eq $false) {
                $resultMarkdown += "`n`n"
                $resultMarkdown += "**Additionally, this application has **$($App.UnmatchedActivities.Count)** unmatched activity endpoint(s) that could not be resolved to a known permission. The least-privilege analysis for this application is incomplete. Manual review is required to confirm its permission posture.**`n`n"
                $resultMarkdown += "| Unmatched Endpoints |`n"
                $resultMarkdown += "| --- |`n"
                foreach ($activity in ($App.UnmatchedActivities | Select-Object -First 5)) {
                    $resultMarkdown += "| ``$($activity.Method) $($activity.Path)`` |`n"
                }
            }

            if ($App.OptimalPermissions.Count -gt 0) {
                $resultMarkdown += "`n`n"
                $resultMarkdown += "The following permission table is the OptimalPermissions result for this application, which represents the minimum set of permissions required to support its recorded activity. Compare this table to the assigned permissions above to identify which permissions can be safely removed.`n`n"
                $resultMarkdown += "| Permission | Scope |`n"
                $resultMarkdown += "| --- | --- |`n"
                foreach ($perm in ($App.OptimalPermissions | Sort-Object Permission, ScopeType)) {
                    $resultMarkdown += "| $($perm.Permission) | $($perm.ScopeType) |`n"
                }
            }


        }

        Add-MtTestResultDetail -Result $resultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
