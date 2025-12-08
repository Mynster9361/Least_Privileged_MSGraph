---
external help file: LeastPrivilegedMSGraph-help.xml
Module Name: LeastPrivilegedMSGraph
online version: https://docs.microsoft.com/en-us/azure/azure-monitor/logs/api/overview
schema: 2.0.0
---

# Initialize-LogAnalyticsApi

## SYNOPSIS
Initializes and registers the Log Analytics API service for use with Entra authentication.

## SYNTAX

```
Initialize-LogAnalyticsApi [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function registers the Azure Log Analytics API service with the Entra service registry,
enabling authenticated queries against Log Analytics workspaces using the api.loganalytics.azure.com
endpoint.
It is required before making any Log Analytics queries via Invoke-EntraRequest.

The function performs the following operations:
1.
Checks if the LogAnalytics service is already registered
2.
If not registered, configures the service with appropriate endpoints and settings
3.
Registers the service with Register-EntraService
4.
Returns status information about the registration

Service Configuration:
The registration includes:
- **Service Name**: "LogAnalytics"
- **API Endpoint**: https://api.loganalytics.azure.com
- **OAuth Resource**: https://api.loganalytics.io (for token acquisition)
- **Default Headers**: Content-Type: application/json
- **Token Refresh**: Enabled (automatic token renewal)
- **Help URL**: Microsoft documentation link

Key Features:
- **Idempotent**: Safe to call multiple times (checks before registering)
- **Session Scope**: Registration persists for PowerShell session lifetime
- **Error Tolerant**: Returns clear status instead of failing on re-registration
- **Verbose Logging**: Detailed status messages for troubleshooting

This is a **one-time setup per PowerShell session**, though it's safe to call multiple times
as it checks for existing registration before attempting to register again.

Use Cases:
- **Module Initialization**: Setup before querying Log Analytics
- **Script Automation**: Ensure service is registered in automated workflows
- **Multi-Service Scripts**: Register alongside Graph API services
- **Troubleshooting**: Verify service registration status

## EXAMPLES

### EXAMPLE 1
```
Initialize-LogAnalyticsApi
```

ServiceName       : LogAnalytics
AlreadyRegistered : False
Status           : NewlyRegistered

Description:
Registers the Log Analytics API service for the first time in the session.
The service is now ready for authentication and queries.

### EXAMPLE 2
```
$result = Initialize-LogAnalyticsApi
if ($result.Status -eq 'NewlyRegistered') {
    "Log Analytics API is now ready for use"
} else {
    "Log Analytics API was already initialized"
}
```

Description:
Captures the registration result and provides feedback based on whether
the service was newly registered or already available.

### EXAMPLE 3
```
# Complete authentication workflow
Initialize-LogAnalyticsApi
Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $secret -Service 'LogAnalytics'
```

$workspaceId = "12345678-1234-1234-1234-123456789012"
$query = "MicrosoftGraphActivityLogs | where TimeGenerated \> ago(7d) | take 10"
$result = Invoke-EntraRequest -Service 'LogAnalytics' -ApiUrl "/v1/workspaces/$workspaceId/query" -Method POST -Body @{query = $query}

Description:
Complete workflow showing initialization, authentication, and querying Log Analytics.
This is the typical pattern for using the module with Log Analytics.

### EXAMPLE 4
```
Initialize-LogAnalyticsApi -Verbose
```

VERBOSE: LogAnalytics service was already registered.
Skipping initialization.
ServiceName       : LogAnalytics
AlreadyRegistered : True
Status           : AlreadyRegistered

Description:
Runs with verbose output showing the service was already configured.
Useful for troubleshooting and understanding script behavior.

### EXAMPLE 5
```
# Register multiple services in a script
Initialize-LogAnalyticsApi | Out-Null
Connect-EntraService -Service 'GraphBeta'
Connect-EntraService -Service 'LogAnalytics' -ClientID $clientId -TenantID $tenantId -ClientSecret $secret
```

$apps = Get-AppRoleAssignment
$appsWithActivity = $apps | Get-AppActivityData -WorkspaceId $workspaceId -Days 30
$analysis = $appsWithActivity | Get-PermissionAnalysis

Description:
Shows how to initialize Log Analytics alongside Graph API services for complete
permission analysis workflows.
Output is suppressed with Out-Null since we only
care about the side effect (registration).

### EXAMPLE 6
```
# Verify service registration status
Initialize-LogAnalyticsApi
$service = Get-EntraService -Name 'LogAnalytics'
```

if ($service) {
    "Service URL: $($service.ServiceUrl)"
    "OAuth Resource: $($service.Resource)"
    "Status: Ready for authentication"
}

Description:
Initializes the service and then verifies its configuration by retrieving
the registered service details.

### EXAMPLE 7
```
# Error handling in automation
try {
    $init = Initialize-LogAnalyticsApi -ErrorAction Stop
    "Initialization $($init.Status): $($init.ServiceName)"
```

Connect-EntraService -Service 'LogAnalytics' -ClientID $clientId -TenantID $tenantId -ClientSecret $secret -ErrorAction Stop
    "Authentication successful"
}
catch {
    Write-Error "Failed to setup Log Analytics API: $_"
    exit 1
}

Description:
Demonstrates proper error handling for automated scripts and CI/CD pipelines.
Uses -ErrorAction Stop to ensure failures are caught and handled appropriately.

## PARAMETERS

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### PSCustomObject
### Returns an object with the following properties:
### PSTypeName (String)
###     Type name for PowerShell formatting system
###     Value: "Entra.ServiceRegistration"
### ServiceName (String)
###     The name of the registered service
###     Value: "LogAnalytics"
### AlreadyRegistered (Boolean)
###     Indicates if service was previously registered
###     - True: Service existed before this call
###     - False: Service was newly registered by this call
### Status (String)
###     Human-readable registration status
###     Values:
###     - "AlreadyRegistered": Service was already configured
###     - "NewlyRegistered": Service was registered by this call
## NOTES
Prerequisites:
- EntraService module must be loaded and available
- Register-EntraService and Get-EntraService cmdlets must be present
- Must be called before any Log Analytics API operations
- No Azure authentication required for initialization (only registration)

Service Configuration Details:
The function registers the following configuration:

Service URL: https://api.loganalytics.azure.com
- Primary API endpoint for Log Analytics queries
- Used for all workspace query operations

OAuth Resource: https://api.loganalytics.io
- Azure AD resource identifier for token acquisition
- Required for obtaining access tokens

Default Headers:
- Content-Type: application/json (required for query API)

Token Management:
- Token refresh enabled (NoRefresh = $false)
- Automatic token renewal before expiration
- No manual token management required

Idempotency and Safety:
- Function is **idempotent** - safe to call multiple times
- Checks for existing registration before proceeding
- Returns status indicating whether registration was performed
- No side effects if service already registered
- Does not re-register or overwrite existing configuration

Session Scope and Persistence:
- Registration persists for the **current PowerShell session only**
- Must be re-initialized in new PowerShell sessions
- Does not persist across PowerShell restarts
- Not stored in profile or registry
- Each script/session must call initialization

Error Handling:
- Uses -ErrorAction SilentlyContinue when checking existing registration
- Returns cleanly if service already registered (no error)
- Throws detailed error if registration fails
- Uses Write-Error for registration failures
- Error messages include full exception details

Logging Levels:
- **Write-PSFMessage -Level Debug -Message**: Detailed processing steps (use -Debug switch)
  * Service registration check
  * Registration success confirmation
  * Status determination
- **Write-PSFMessage -Level Verbose -Message "Your message here"**: Key status messages (use -Verbose switch)
  * Already registered notification
  * New registration notification
- **Write-Error**: Registration failures
  * Exception details
  * Full error context

Return Object:
The returned PSCustomObject includes:
- **PSTypeName**: Enables custom formatting if defined
- **ServiceName**: Always "LogAnalytics" for consistency
- **AlreadyRegistered**: Boolean for conditional logic
- **Status**: Human-readable string for display

Common Patterns:

Silent initialization (most common):
\`\`\`powershell
Initialize-LogAnalyticsApi | Out-Null
\`\`\`

Conditional logic based on status:
\`\`\`powershell
$result = Initialize-LogAnalyticsApi
if (-not $result.AlreadyRegistered) {
    "Service newly registered - first use in this session"
}
\`\`\`

Error handling in production:
\`\`\`powershell
try {
    Initialize-LogAnalyticsApi -ErrorAction Stop
} catch {
    Write-Error "Failed to initialize Log Analytics API: $_"
    exit 1
}
\`\`\`

Troubleshooting:

If "Register-EntraService not found" error:
- Ensure EntraService module is loaded: Import-Module EntraService
- Check module availability: Get-Module EntraService -ListAvailable
- Verify correct module version installed

If registration fails:
- Check error message for specific failure reason
- Verify no conflicting service registration exists
- Try restarting PowerShell session
- Ensure module dependencies are met

If Get-EntraService fails during initialization:
- This is expected behavior (uses SilentlyContinue)
- Function handles this gracefully
- Only causes issue if Get-EntraService is missing entirely

Integration with Other Commands:
This function is typically used in conjunction with:
- Connect-EntraService: Authenticate to Log Analytics
- Invoke-EntraRequest: Execute Log Analytics queries
- Get-AppActivityData: Retrieve application activity from logs
- Get-AppThrottlingData: Get throttling statistics from logs

Best Practices:
- Call at the beginning of scripts that use Log Analytics
- Include in module initialization code
- Use Out-Null if you don't need the return value
- Always call before Connect-EntraService for Log Analytics
- Include error handling in production automation
- Use -Verbose during development and troubleshooting

Performance:
- Initialization is very fast (\< 100ms)
- No network calls made during registration
- Negligible memory footprint
- No impact on subsequent API calls

Related Cmdlets:
- Register-EntraService: Underlying registration function
- Get-EntraService: Retrieve registered service configuration
- Connect-EntraService: Authenticate to registered services
- Invoke-EntraRequest: Make API calls to registered services

## RELATED LINKS

[https://docs.microsoft.com/en-us/azure/azure-monitor/logs/api/overview](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/api/overview)

[https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Initialize-LogAnalyticsApi.html](https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Initialize-LogAnalyticsApi.html)

