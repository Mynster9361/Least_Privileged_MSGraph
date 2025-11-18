function Initialize-LogAnalyticsApi {
<#
.SYNOPSIS
    Initializes and registers the Log Analytics API service for use with Entra authentication.

.DESCRIPTION
    This function registers the Azure Log Analytics API service with the Entra service registry,
    enabling authenticated queries against Log Analytics workspaces using the api.loganalytics.azure.com
    endpoint. It is required before making any Log Analytics queries via Invoke-EntraRequest.
    
    The function performs the following operations:
    1. Checks if the LogAnalytics service is already registered
    2. If not registered, configures the service with appropriate endpoints and settings
    3. Registers the service with Register-EntraService
    4. Returns status information about the registration
    
    The registration includes:
    - Service name: "LogAnalytics"
    - API endpoint: https://api.loganalytics.azure.com
    - OAuth resource: https://api.loganalytics.io
    - Default headers for JSON content
    - Token refresh enabled
    
    This is a one-time setup per PowerShell session, though it's safe to call multiple times
    as it checks for existing registration before attempting to register again.

.PARAMETER None
    This function does not accept any parameters.

.OUTPUTS
    PSCustomObject
    Returns an object with the following properties:
    - PSTypeName: Type name for formatting (Entra.ServiceRegistration)
    - ServiceName: The name of the registered service ("LogAnalytics")
    - AlreadyRegistered: Boolean indicating if service was previously registered
    - Status: String indicating registration status ("AlreadyRegistered" or "NewlyRegistered")

.EXAMPLE
    Initialize-LogAnalyticsApi
    
    ServiceName       : LogAnalytics
    AlreadyRegistered : False
    Status           : NewlyRegistered
    
    Registers the Log Analytics API service for the first time in the session.

.EXAMPLE
    $result = Initialize-LogAnalyticsApi
    if ($result.Status -eq 'NewlyRegistered') {
        Write-Host "Log Analytics API is now ready for use"
    }
    
    Captures the registration result and checks if it was newly registered.

.EXAMPLE
    # Typical workflow
    Initialize-LogAnalyticsApi
    Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $secret -ServiceName 'LogAnalytics'
    $activity = Get-AppActivityFromLogs -logAnalyticsWorkspace $workspaceId -days 30 -spId $spId
    
    Complete authentication and service setup workflow before querying Log Analytics.

.EXAMPLE
    Initialize-LogAnalyticsApi -Verbose -Debug
    
    ServiceName       : LogAnalytics
    AlreadyRegistered : True
    Status           : AlreadyRegistered
    
    VERBOSE: LogAnalytics service was already registered. Skipping initialization.
    
    Runs with verbose and debug output, showing the service was already configured.

.NOTES
    Prerequisites:
    - EntraService module must be loaded
    - Register-EntraService and Get-EntraService cmdlets must be available
    - Must be called before any Log Analytics API operations
    
    Service Configuration:
    - Service URL: https://api.loganalytics.azure.com
    - OAuth Resource: https://api.loganalytics.io
    - Default Content-Type: application/json
    - Token Refresh: Enabled (NoRefresh = $false)
    - Help URL: https://docs.microsoft.com/en-us/azure/azure-monitor/logs/api/overview
    
    Idempotency:
    - Safe to call multiple times
    - Checks for existing registration before proceeding
    - Returns status indicating whether registration was performed
    
    Error Handling:
    - Uses -ErrorAction SilentlyContinue when checking existing registration
    - Throws detailed error if registration fails
    - Uses Write-Error for registration failures
    
    Session Scope:
    - Registration persists for the current PowerShell session
    - Must be re-initialized in new sessions
    - Does not persist across PowerShell restarts
    
    This function uses Write-Verbose for status messages, Write-Debug for detailed processing
    information, and Write-Error for exceptions. It returns a typed PSCustomObject for easy
    status checking and pipeline operations.

.LINK
    https://docs.microsoft.com/en-us/azure/azure-monitor/logs/api/overview

#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param ()
    
    begin {
        Write-Debug "Checking if LogAnalytics service is already registered..."
        
        $verifyRegistration = Get-EntraService -Name 'LogAnalytics' -ErrorAction SilentlyContinue
        if ($null -ne $verifyRegistration) {
            Write-Debug "LogAnalytics service is already registered."
            $alreadyRegistered = $true
        }
        else {
            $alreadyRegistered = $false
        }
    }

    process {
        # Skip registration if already registered
        if ($alreadyRegistered) {
            Write-Verbose "LogAnalytics service was already registered. Skipping initialization."
            return
        }

        Write-Verbose "Registering LogAnalytics service..."
        
        $LogAnalyticsCfg = @{
            Name          = 'LogAnalytics'
            ServiceUrl    = 'https://api.loganalytics.azure.com'
            Resource      = 'https://api.loganalytics.io'
            DefaultScopes = @()
            HelpUrl       = 'https://docs.microsoft.com/en-us/azure/azure-monitor/logs/api/overview'
            Header        = @{
                'Content-Type' = 'application/json'
            }
            NoRefresh     = $false
        }
        
        try {
            Register-EntraService @LogAnalyticsCfg
            Write-Debug "LogAnalytics service registered successfully."
        }
        catch {
            Write-Error "Failed to register LogAnalytics service: $_"
            throw
        }
    }
    
    end {
        $statusMessage = if ($alreadyRegistered) {
            "AlreadyRegistered"
        }
        else {
            "NewlyRegistered"
        }
        
        Write-Debug "LogAnalytics service initialization completed. Status: $statusMessage"

        # Return structured object with clear status
        return [PSCustomObject]@{
            PSTypeName        = 'Entra.ServiceRegistration'
            ServiceName       = 'LogAnalytics'
            AlreadyRegistered = $alreadyRegistered
            Status            = $statusMessage
        }
    }
}