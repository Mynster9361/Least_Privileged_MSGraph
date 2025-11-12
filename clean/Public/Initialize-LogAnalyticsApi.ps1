<#
.SYNOPSIS
    Initializes and registers the Log Analytics API service for use with Entra authentication.

.DESCRIPTION
    The Initialize-LogAnalyticsApi function registers the Azure Log Analytics API service
    with the Entra service registry. This enables authenticated queries against Log Analytics
    workspaces using the api.loganalytics.azure.com endpoint.
    
    The function checks if the service is already registered before attempting registration
    to avoid duplicate entries.

.PARAMETER None
    This function does not accept any parameters.

.OUTPUTS
    PSCustomObject
    Returns an object with the following properties:
    - ServiceName: The name of the registered service (LogAnalytics)
    - AlreadyRegistered: Boolean indicating if service was previously registered
    - Status: String indicating 'AlreadyRegistered' or 'NewlyRegistered'

.EXAMPLE
    PS> Initialize-LogAnalyticsApi
    
    ServiceName       : LogAnalytics
    AlreadyRegistered : False
    Status           : NewlyRegistered

    Registers the Log Analytics API service for the first time.

.EXAMPLE
    PS> $result = Initialize-LogAnalyticsApi
    PS> if ($result.AlreadyRegistered) {
    >>     Write-Host "Service was already configured"
    >> }

    Checks the registration status and takes action based on the result.

.NOTES
    The function uses the following Log Analytics API configuration:
    - Service URL: https://api.loganalytics.azure.com
    - Resource: https://api.loganalytics.io
    - Authentication: Azure AD via Entra service

.LINK

#>
function Initialize-LogAnalyticsApi {
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