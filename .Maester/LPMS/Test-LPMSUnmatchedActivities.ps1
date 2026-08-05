function Test-LPMSUnmatchedActivities {
    <#
    .SYNOPSIS
        Checks whether any service principal has Graph API activity that could not be matched
        to a known endpoint for least-privilege analysis.

    .DESCRIPTION
        A service principal with unmatched activities (MatchedAllActivity = $false) has made
        Graph API calls whose endpoints could not be resolved to a minimum-required permission.
        This means its ExcessPermissions and OptimalPermissions results are incomplete — the
        tool cannot confidently recommend permission removal for that application.

        The result is reported with the Investigate status because unmatched activities are not
        a direct security failure but require manual review: the unmatched endpoint may need a
        permission mapping update, or the application may be using a deprecated/undocumented API.

        Returns $true  when all service principals have fully matched activity.
        Returns $false when one or more service principals have unmatched activity (flagged as Investigate).
        Returns $null  when the check could not run.

    .EXAMPLE
        Test-LPMSUnmatchedActivities

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
        $testResult = ($App.MatchedAllActivity -ne $false)
        $portalLink = "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Permissions/objectId/{0}"

        if ($testResult) {
            $resultMarkdown = "Well done! All Graph API activity for **$($App.PrincipalName)** was successfully matched to a known endpoint. The permission analysis is complete."
        } else {
            $unmatchedCount = if ($null -ne $App.UnmatchedActivities) { @($App.UnmatchedActivities).Count } else { 0 }
            $unmatchedUris = if ($unmatchedCount -gt 0) {
                ($App.UnmatchedActivities | Select-Object -First 5 | ForEach-Object { "``$($_.Method) $($_.Path)``" }) -join '<br/>'
            } else {
                '_Unknown_'
            }
            $resultMarkdown = "**[$($App.PrincipalName)]($($portalLink -f $App.PrincipalId))** has Graph API activity that could not be matched to a known endpoint.`n`n"
            $resultMarkdown += "The least-privilege analysis for this application may be incomplete. Manual review is required to confirm its permission posture.`n`n"
            $resultMarkdown += "| Unmatched Endpoints |`n"
            $resultMarkdown += "| --- |`n"
            $resultMarkdown += "| $unmatchedUris |`n"
        }

        Add-MtTestResultDetail -Result $resultMarkdown -Investigate:(-not $testResult)
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
