function Assert-LPMSGraph {
    <#
.SYNOPSIS
    Validates all prerequisites and requirements for using the LeastPrivilegedMSGraph module.

.DESCRIPTION
    The Assert-LPMSGraph function performs a comprehensive validation of all prerequisites required
    to successfully use the LeastPrivilegedMSGraph module. It checks multiple components including:

    - Entra Service Connectivity: Verifies authentication to required services (LogAnalytics, Graph, Azure)
    - Azure AD Premium License: Confirms that Microsoft Entra ID P1 or higher license is available
    - Diagnostic Settings: Validates that MicrosoftGraphActivityLogs diagnostic settings are configured
    - Log Analytics Access: Tests workspace access and verifies MicrosoftGraphActivityLogs data availability
    - Microsoft Graph API Permissions: Confirms sufficient permissions to read applications

    The function returns a detailed result object containing the overall status, individual check results,
    tenant ID, and timestamp. Each check includes a name, status (Passed/Failed), descriptive message,
    and any error details encountered.

    This function is useful for troubleshooting setup issues and confirming that the environment is
    properly configured before performing permission analysis operations.

.EXAMPLE
    PS C:\> Assert-LPMSGraph

    Runs all prerequisite checks and returns a detailed validation report.

.EXAMPLE
    PS C:\> $result = Assert-LPMSGraph
    PS C:\> $result.Checks | Where-Object Status -eq 'Failed'

    Stores the validation result and filters to show only failed checks.

.EXAMPLE
    PS C:\> Assert-LPMSGraph | Select-Object -ExpandProperty Checks | Format-Table Name, Status, Message -AutoSize

    Displays all validation checks in a formatted table showing name, status, and message.

.OUTPUTS
    PSCustomObject
    Returns an object with the following properties:
    - OverallStatus: String indicating "Passed" or "Failed"
    - Checks: Array of check result objects, each containing Name, Status, Message, and Error properties
    - TenantId: The current tenant ID from the authentication token
    - Timestamp: UTC timestamp when the validation was performed

.NOTES
    Prerequisites:
    - Must be connected to Entra services using Connect-EntraService
    - Requires access to Azure AD tenant with appropriate permissions
    - Requires Azure AD Premium P1 or higher license for activity logging

    This function does not modify any settings or configurations. It only performs read-only validation checks.

.LINK
    https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Assert-LPMSGraph.html
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
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
        $step = "Entra Service Connectivity"
        $tokens = Get-EntraToken
        $requiredServices = @('LogAnalytics', 'Graph', 'Azure')
        $connectedServices = $tokens.Service

        $missingServices = $requiredServices | Where-Object { $_ -notin $connectedServices }
        if ($missingServices.Count -gt 0) {
            $overallSuccess = $false
            [void]$testResults.Add([PSCustomObject]@{
                    Name    = $step
                    Status  = "Failed"
                    Message = "Missing authentication for services: $($missingServices -join ', '). Please run Connect-EntraService with these services."
                    Error   = $null
                })
        }
        else {
            [void]$testResults.Add([PSCustomObject]@{
                    Name    = $step
                    Status  = "Passed"
                    Message = "Successfully authenticated to required services: $($connectedServices -join ', ')"
                    Error   = $null
                })
            Write-PSFMessage -Level Verbose -Message "Entra service connectivity check passed"
        }
    }
    catch {
        $overallSuccess = $false
        [void]$testResults.Add([PSCustomObject]@{
                Name    = $step
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
        $step = "Azure AD Premium License"
        $skus = Invoke-EntraRequest -Method GET -Path "/subscribedSkus" -Service "Graph" | Where-Object { $_.servicePlans.servicePlanName -match "AAD_PREMIUM" }
        if ($null -eq $skus -or $skus.Count -eq 0) {
            $overallSuccess = $false
            [void]$testResults.Add([PSCustomObject]@{
                    Name    = $step
                    Status  = "Failed"
                    Message = "Microsoft Entra ID P1 or higher is required for activity logging"
                    Error   = $null
                })
        }
        else {
            $skuNames = $skus.skuPartNumber | Where-Object { $_ -match "AAD_PREMIUM" } | Sort-Object -Unique | Join-String -Separator ', '
            [void]$testResults.Add([PSCustomObject]@{
                    Name    = $step
                    Status  = "Passed"
                    Message = "Found required licenses: $skuNames"
                    Error   = $null
                })
            Write-PSFMessage -Level Verbose -Message "License check passed: $skuNames"
        }
    }
    catch {
        $overallSuccess = $false
        [void]$testResults.Add([PSCustomObject]@{
                Name    = $step
                Status  = "Failed"
                Message = "Azure AD Premium P1 or higher is required for activity logging. Unable to verify license."
                Error   = $_.Exception.Message
            })
        Write-PSFMessage -Level Warning -Message "License check failed: $($_.Exception.Message)"
    }
    #endregion License Requirement Check

    #region Diagnostic Settings Check
    # This will verify that diagnostic settings are properly configured for MicrosoftGraphActivityLogs

    Write-PSFMessage -Level Verbose -Message "Checking diagnostic settings for MicrosoftGraphActivityLogs..."

    try {
        $step = "Diagnostic Settings Configuration"
        $uri = "/providers/microsoft.aadiam/diagnosticSettings"
        $diagSettings = Invoke-EntraRequest -Method GET -Path $uri -Service "Azure" -Query @{ 'api-version' = '2017-04-01-preview' } | Where-Object { $_.properties.logs -match "MicrosoftGraphActivityLogs" } -WarningAction SilentlyContinue
        if ($null -eq $diagSettings -or $diagSettings.Count -eq 0) {
            Write-PSFMessage -Level Debug -Message "No diagnostic settings found for MicrosoftGraphActivityLogs"
            $overallSuccess = $false
            [void]$testResults.Add([PSCustomObject]@{
                    Name    = $step
                    Status  = "Failed"
                    Message = "MicrosoftGraphActivityLogs diagnostic settings are not configured or could not be retrieved"
                    Error   = $null
                })
        }
        else {
            foreach ($setting in $diagSettings) {
                if ($setting.properties.logs -match "MicrosoftGraphActivityLogs") {
                    Write-PSFMessage -Level Debug -Message "Found diagnostic setting: $($setting.name)"
                    [void]$testResults.Add([PSCustomObject]@{
                            Name    = $step
                            Status  = "Passed"
                            Message = "MicrosoftGraphActivityLogs diagnostic settings are configured in setting: $($setting.name) - Workspace: $($setting.properties.workspaceId)"
                            Error   = $null
                        })
                }
            }
            Write-PSFMessage -Level Verbose -Message "Diagnostic settings check passed"
        }
    }
    catch {
        $overallSuccess = $false
        [void]$testResults.Add([PSCustomObject]@{
                Name    = $step
                Status  = "Failed"
                Message = "Cannot retrieve diagnostic settings for MicrosoftGraphActivityLogs"
                Error   = $_.Exception.Message
            })
        Write-PSFMessage -Level Verbose -Message "Diagnostic settings check failed: $($_.Exception.Message)"
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
        $step = "Log Analytics Workspace Access"
        $response = Invoke-EntraRequest -Service "LogAnalytics" -Method POST -Path "/v1$($diagSettings.properties.workspaceId)/query" -Body ($body | ConvertTo-Json -Depth 10)

        if ($null -eq $response.tables -or $null -eq $response.tables.rows -or $response.tables.rows.Count -eq 0) {
            $overallSuccess = $false
            [void]$testResults.Add([PSCustomObject]@{
                    Name    = $step
                    Status  = "Failed"
                    Message = "No MicrosoftGraphActivityLogs data found in workspace $WorkspaceId. Ensure diagnostic settings are correctly configured. And you have waited sufficient time for data to populate."
                    Error   = $null
                })
        }
        else {
            [void]$testResults.Add([PSCustomObject]@{
                    Name    = $step
                    Status  = "Passed"
                    Message = "Successfully queried workspace $WorkspaceId and found MicrosoftGraphActivityLogs data"
                    Error   = $null
                })
            Write-PSFMessage -Level Verbose -Message "Log Analytics access check passed"
        }
    }
    catch {
        $overallSuccess = $false
        [void]$testResults.Add([PSCustomObject]@{
                Name    = $step
                Status  = "Failed"
                Message = "Cannot access or query Log Analytics workspace. Ensure you have proper access permissions. Least privileged role 'Log Analytics Reader' on the Log Analytics workspace."
                Error   = $_.Exception.Message
            })
        Write-PSFMessage -Level Warning -Message "Log Analytics access check failed: $($_.Exception.Message)"
    }
    #endregion Log Analytics Access Check

    #region Microsoft Graph API Permissions Check
    Write-PSFMessage -Level Verbose -Message "Verifying Microsoft Graph API permissions..."

    try {
        $step = "Microsoft Graph API Permissions"
        $apps = Invoke-EntraRequest -Method GET -Path "/applications" -Service "Graph" -Query @{ '$top' = '1' } -NoPaging

        [void]$testResults.Add([PSCustomObject]@{
                Name    = $step
                Status  = "Passed"
                Message = "Successfully retrieved applications from Microsoft Graph"
                Error   = $null
            })
        Write-PSFMessage -Level Verbose -Message "Microsoft Graph permissions check passed"
    }
    catch {
        $overallSuccess = $false
        [void]$testResults.Add([PSCustomObject]@{
                Name    = $step
                Status  = "Failed"
                Message = "Cannot read applications from Microsoft Graph. Requires Application.Read.All permission or application reader role."
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
    return $result
}
