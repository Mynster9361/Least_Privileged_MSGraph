function Test-LPMSNoActivity {
    <#
    .SYNOPSIS
        Checks whether any service principal has been granted Graph API permissions but recorded
        no API activity during the analysis window.

    .DESCRIPTION
        A service principal that holds permissions but made zero Graph API calls during the
        analysis period is a candidate for decommissioning or permission removal.

        Common causes:
        - The application was replaced by a newer version but the old registration was not cleaned up.
        - The application is seasonal and only runs at certain times (consider widening the analysis window).
        - The application only uses delegated flows driven by end-user sign-ins that did not occur.
        - The service principal was created in error or as a test and never put into production.

        Results are reported with the Investigate status because zero activity does not
        automatically mean the application is unused — it may simply be outside its active period.

        Only applications with at least one assigned permission (AppRoleCount > 0) are evaluated.
        Service principals with no permissions assigned are excluded.

        Returns $true  when every permissioned service principal has recorded at least one API call.
        Returns $false when one or more permissioned service principals have no recorded activity.
        Returns $null  when the check could not run.

    .EXAMPLE
        Test-LPMSNoActivity

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
        $days = if ($env:LPMS_DAYS_TO_QUERY) { [int]$env:LPMS_DAYS_TO_QUERY } else { 30 }

        $hasActivity = ($null -ne $App.Activity -and @($App.Activity).Count -gt 0)
        $testResult = $hasActivity

        if ($testResult) {
            $resultMarkdown = "Well done! **$($App.PrincipalName)** recorded at least one Graph API call during the last $days days."
        }
        else {
            $portalLink = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Permissions/objectId/{0}"
            $permCount = $App.AppRoleCount
            $permTypes = ($App.AppRoles | Select-Object -ExpandProperty PermissionType -Unique) -join ', '
            $resultMarkdown = "**[$($App.PrincipalName)]($($portalLink -f $App.PrincipalId))** has **$permCount** assigned permission(s) but **no recorded activity** in the last $days days.`n`n"
            $resultMarkdown += "This application may be stale, unused, or operating outside the analysis window. Review it and consider revoking permissions or decommissioning the registration if it is no longer needed.`n`n"
            $resultMarkdown += "| Assigned Permissions | Permission Types |`n"
            $resultMarkdown += "| --- | --- |`n"
            $resultMarkdown += "| $permCount | $permTypes |`n"
        }

        Add-MtTestResultDetail -Result $resultMarkdown -Investigate:(-not $testResult)
        return $testResult
    }
    catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
