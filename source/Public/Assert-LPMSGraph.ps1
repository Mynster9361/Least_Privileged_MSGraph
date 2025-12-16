function Assert-LPMSGraph {
    <#
.SYNOPSIS
    Validates prerequisites and permissions for LeastPrivilegedMSGraph module functionality.

.DESCRIPTION
    This function performs comprehensive validation checks to ensure that the environment
    is properly configured for using the LeastPrivilegedMSGraph module. It verifies:

    - Entra service connectivity (Log Analytics, Microsoft Graph, Azure)
    - Azure AD Premium P1 license availability (required for activity logs)
    - Log Analytics workspace access and data availability
    - Microsoft Graph API permissions for reading applications

    The function returns a detailed test result object showing the status of each check,
    making it easy to identify any configuration issues before running permission analysis.

.PARAMETER WorkspaceId
    The Azure Log Analytics workspace ID (GUID) where Microsoft Graph activity logs are stored.
    This workspace must contain the MicrosoftGraphActivityLogs table.

.OUTPUTS
    PSCustomObject
    Returns a test result object with the following properties:

    OverallStatus (String)
        "Passed" if all checks succeeded, "Failed" if any check failed

    Checks (Array of PSCustomObject)
        Array containing results for each validation check:
        - Name: Description of the check
        - Status: "Passed", "Failed", or "Skipped"
        - Message: Detailed message about the check result
        - Error: Error details if the check failed (null if passed)

    TenantId (String)
        The tenant ID of the currently authenticated session

    Timestamp (DateTime)
        When the validation was performed

.EXAMPLE

    Assert-LPMSGraph -WorkspaceId $workspaceId -Verbose

.NOTES
    Prerequisites:
    - Must call Initialize-LogAnalyticsApi before running this function
    - Must be authenticated via Connect-EntraService with appropriate services
    - Requires the following permissions:
      * Directory.Read.All (to read subscribed SKUs and applications)
      * Log Analytics Reader role on the workspace

    Required Services:
    - LogAnalytics: For querying activity logs
    - Graph or GraphBeta: For reading tenant information
    - Azure: For checking diagnostic settings (work in progress)

.LINK
    https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Assert-LPMSGraph.html
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$WorkspaceId
    )

    $testResults = [System.Collections.ArrayList]::new()
    $overallSuccess = $true

    # Get current tenant ID if available
    $currentTenantId = $null
    try {
        $token = Get-EntraToken | Select-Object -First 1
        if ($token) {
            $currentTenantId = $token.TenantId
        }
    }
    catch {
        Write-PSFMessage -Level Debug -Message "Could not retrieve tenant ID from token"
    }

    Write-PSFMessage -Level Verbose -Message "Starting LeastPrivilegedMSGraph prerequisites validation..."

    #region Service Connectivity Check
    Write-PSFMessage -Level Verbose -Message "Checking Entra service connectivity..."

    try {
        $tokens = Get-EntraToken
        $requiredServices = @('LogAnalytics', 'Graph')
        $connectedServices = $tokens.Service

        $missingServices = $requiredServices | Where-Object { $_ -notin $connectedServices }

        if ($missingServices.Count -gt 0) {
            throw "Missing authentication for services: $($missingServices -join ', '). Please run Connect-EntraService with these services."
        }

        [void]$testResults.Add([PSCustomObject]@{
                Name    = "Entra Service Connectivity"
                Status  = "Passed"
                Message = "Successfully authenticated to required services: $($connectedServices -join ', ')"
                Error   = $null
            })
        Write-PSFMessage -Level Verbose -Message "Entra service connectivity check passed"
    }
    catch {
        $overallSuccess = $false
        [void]$testResults.Add([PSCustomObject]@{
                Name    = "Entra Service Connectivity"
                Status  = "Failed"
                Message = "Failed to verify service connectivity"
                Error   = $_.Exception.Message
            })
        Write-PSFMessage -Level Warning -Message "Entra service connectivity check failed: $($_.Exception.Message)"
    }
    #endregion Service Connectivity Check

    #region License Requirement Check
    Write-PSFMessage -Level Verbose -Message "Checking Azure AD Premium license availability..."

    try {
        $skus = Invoke-EntraRequest -Method GET -Path "/subscribedSkus" -Service "Graph" | Where-Object { $_.servicePlans.servicePlanName -match "AAD_PREMIUM" }

        if ($null -eq $skus -or $skus.Count -eq 0) {
            throw "No AAD Premium SKUs found. Microsoft Entra ID P1 or higher is required for MicrosoftGraphActivityLogs."
        }

        $skuNames = $skus.skuPartNumber | Where-Object { $_ -match "AAD_PREMIUM" } | Sort-Object -Unique | Join-String -Separator ', '
        [void]$testResults.Add([PSCustomObject]@{
                Name    = "Azure AD Premium License"
                Status  = "Passed"
                Message = "Found required licenses: $skuNames"
                Error   = $null
            })
        Write-PSFMessage -Level Verbose -Message "License check passed: $skuNames"
    }
    catch {
        $overallSuccess = $false
        [void]$testResults.Add([PSCustomObject]@{
                Name    = "Azure AD Premium License"
                Status  = "Failed"
                Message = "Azure AD Premium P1 or higher is required for activity logging"
                Error   = $_.Exception.Message
            })
        Write-PSFMessage -Level Warning -Message "License check failed: $($_.Exception.Message)"
    }
    #endregion License Requirement Check

    #region Diagnostic Settings Check (Work in Progress)
    # TODO: Still working on this check
    # This will verify that diagnostic settings are properly configured for MicrosoftGraphActivityLogs

    Write-PSFMessage -Level Verbose -Message "Checking diagnostic settings for MicrosoftGraphActivityLogs..."

    try {
        $uri = "/providers/microsoft.aadiam/diagnosticSettingsCategories/MicrosoftGraphActivityLogs"
        $diagSettings = Invoke-EntraRequest -Method GET -Path $uri -Service "Azure" -Query @{ 'api-version' = '2021-05-01-preview' } -WarningAction SilentlyContinue

        [void]$testResults.Add([PSCustomObject]@{
                Name    = "Diagnostic Settings Configuration"
                Status  = "Passed"
                Message = "MicrosoftGraphActivityLogs diagnostic settings are configured"
                Error   = $null
            })
        Write-PSFMessage -Level Verbose -Message "Diagnostic settings check passed"
    }
    catch {
        $overallSuccess = $false
        [void]$testResults.Add([PSCustomObject]@{
                Name    = "Diagnostic Settings Configuration"
                Status  = "Failed"
                Message = "Diagnostic settings check is under development"
                Error   = $_.Exception.Message
            })
        Write-PSFMessage -Level Verbose -Message "Diagnostic settings check skipped (under development)"
    }

    #endregion Diagnostic Settings Check

    #region Log Analytics Access Check
    Write-PSFMessage -Level Verbose -Message "Verifying Log Analytics workspace access and data availability..."

    try {
        $kqlQuery = @"
MicrosoftGraphActivityLogs
| take 1
"@

        $body = @{
            query            = $kqlQuery
            options          = @{
                truncationMaxSize = 67108864
            }
            workspaceFilters = @{
                regions = @()
            }
        }

        $response = Invoke-EntraRequest -Service "LogAnalytics" -Method POST -Path "/v1/workspaces/$WorkspaceId/query" -Body ($body | ConvertTo-Json -Depth 10)

        if ($null -eq $response.tables -or $null -eq $response.tables.rows -or $response.tables.rows.Count -eq 0) {
            throw "No data returned from Log Analytics workspace. Logs may not be flowing yet or workspace is empty."
        }

        [void]$testResults.Add([PSCustomObject]@{
                Name    = "Log Analytics Workspace Access"
                Status  = "Passed"
                Message = "Successfully queried workspace $WorkspaceId and found MicrosoftGraphActivityLogs data"
                Error   = $null
            })
        Write-PSFMessage -Level Verbose -Message "Log Analytics access check passed"
    }
    catch {
        $overallSuccess = $false
        [void]$testResults.Add([PSCustomObject]@{
                Name    = "Log Analytics Workspace Access"
                Status  = "Failed"
                Message = "Cannot access or query Log Analytics workspace"
                Error   = $_.Exception.Message
            })
        Write-PSFMessage -Level Warning -Message "Log Analytics access check failed: $($_.Exception.Message)"
    }
    #endregion Log Analytics Access Check

    #region Microsoft Graph API Permissions Check
    Write-PSFMessage -Level Verbose -Message "Verifying Microsoft Graph API permissions..."

    try {
        $apps = Invoke-EntraRequest -Method GET -Path "/applications" -Service "Graph" -Query @{ '$top' = '1' } -NoPaging

        [void]$testResults.Add([PSCustomObject]@{
                Name    = "Microsoft Graph API Permissions"
                Status  = "Passed"
                Message = "Successfully retrieved applications from Microsoft Graph"
                Error   = $null
            })
        Write-PSFMessage -Level Verbose -Message "Microsoft Graph permissions check passed"
    }
    catch {
        $overallSuccess = $false
        [void]$testResults.Add([PSCustomObject]@{
                Name    = "Microsoft Graph API Permissions"
                Status  = "Failed"
                Message = "Cannot read applications from Microsoft Graph. Requires Directory.Read.All or Application.Read.All permission"
                Error   = $_.Exception.Message
            })
        Write-PSFMessage -Level Warning -Message "Microsoft Graph permissions check failed: $($_.Exception.Message)"
    }
    #endregion Microsoft Graph API Permissions Check

    # Build final result object
    $result = [PSCustomObject]@{
        OverallStatus = if ($overallSuccess) {
            "Passed"
        }
        else {
            "Failed"
        }
        Checks        = $testResults.ToArray()
        TenantId      = $currentTenantId
        Timestamp     = [datetime]::UtcNow
    }

    # Display summary
    Write-PSFMessage -Level Verbose -Message "`nValidation Summary:"
    Write-PSFMessage -Level Verbose -Message "  Overall Status: $($result.OverallStatus)"
    Write-PSFMessage -Level Verbose -Message "  Passed: $(($testResults | Where-Object { $_.Status -eq 'Passed' }).Count)"
    Write-PSFMessage -Level Verbose -Message "  Failed: $(($testResults | Where-Object { $_.Status -eq 'Failed' }).Count)"
    Write-PSFMessage -Level Verbose -Message "  Skipped: $(($testResults | Where-Object { $_.Status -eq 'Skipped' }).Count)"

    if (-not $overallSuccess) {
        Write-PSFMessage -Level Warning -Message "`nOne or more checks failed. Review the Checks property for details."
    }
    else {
        Write-PSFMessage -Level Verbose -Message "`nAll checks passed! Environment is ready for permission analysis."
    }

    return $result
}

$tenantId = Get-Clipboard
$clientId = Get-Clipboard
$clientSecret = Get-Clipboard | ConvertTo-SecureString -AsPlainText -Force
Initialize-LogAnalyticsApi | Out-Null
Connect-EntraService -Service "LogAnalytics", "Graph", "Azure" -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret
$result = Assert-LPMSGraph -WorkspaceId "we698512-852a-234w-t341-ab0f181d0fa5"
