---
external help file: LeastPrivilegedMSGraph-help.xml
Module Name: LeastPrivilegedMSGraph
online version: https://learn.microsoft.com/en-us/graph/permissions-reference
schema: 2.0.0
---

# Get-AppRoleAssignment

## SYNOPSIS
Retrieves Microsoft Graph app role assignments for all applications in the tenant.

## SYNTAX

```
Get-AppRoleAssignment [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function queries Microsoft Graph to retrieve all app role assignments for Microsoft Graph API
permissions across all service principals in the tenant.
It provides a comprehensive view of which
applications have which Microsoft Graph permissions assigned.

The function performs the following operations:
1.
Retrieves the Microsoft Graph service principal information (appId: 00000003-0000-0000-c000-000000000000)
2.
Fetches all app role assignments using automatic pagination with optimized $select query
3.
Builds a comprehensive lookup table mapping permission IDs to friendly names
4.
Enriches assignments with human-readable permission names and types
5.
Groups assignments by principal (service principal/application)
6.
Returns streamlined objects optimized for analysis and reporting

Permission Types Included:
- **Application Permissions** (appRoles): App-only permissions without user context
- **Resource-Specific Application Permissions**: Permissions for specific resource types
- **Delegated Work Permissions** (publishedPermissionScopes): Permissions requiring user context

The function uses memory optimization techniques including explicit garbage collection
and optimized Graph API queries with $select to reduce payload size, making it suitable
for enterprise tenants with thousands of applications.

Use Cases:
- Security audits: Review all Graph API permissions across the tenant
- Compliance reporting: Document current permission assignments
- Permission inventory: Create baseline of assigned permissions
- Over-privilege detection: Identify applications with excessive permissions
- License management: Understand which apps use which Graph features
- Permission cleanup: Identify candidates for permission removal

## EXAMPLES

### EXAMPLE 1
```
Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret -Service "GraphBeta"
$assignments = Get-AppRoleAssignment
```

Description:
Retrieves all Microsoft Graph app role assignments after authenticating to the tenant.
Output shows all applications and their assigned Graph API permissions.

### EXAMPLE 2
```
$assignments = Get-AppRoleAssignment -Verbose
$overPrivilegedApps = $assignments | Where-Object { $_.AppRoleCount -gt 50 }
```

"Found $($overPrivilegedApps.Count) over-privileged applications:"
$overPrivilegedApps | Sort-Object AppRoleCount -Descending |
    Select-Object PrincipalName, AppRoleCount |
    Format-Table -AutoSize

Description:
Identifies applications with more than 50 assigned Graph permissions (potential over-privileging)
and displays them sorted by permission count.
Uses verbose output to track progress.

### EXAMPLE 3
```
$assignments = Get-AppRoleAssignment
$appOnlyPerms = $assignments | ForEach-Object {
    $app = $_
    $app.AppRoles | Where-Object { $_.PermissionType -eq 'Application' } | ForEach-Object {
        [PSCustomObject]@{
            AppName = $app.PrincipalName
            AppId = $app.PrincipalId
            Permission = $_.FriendlyName
            PermissionId = $_.appRoleId
        }
    }
}
```

$appOnlyPerms | Export-Csv -Path "application-only-permissions.csv" -NoTypeInformation
"Exported $($appOnlyPerms.Count) application-only permissions to CSV"

Description:
Extracts all application-scoped (app-only) permissions across all applications
and exports them to CSV for security review or compliance documentation.

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

### System.Object[]
### Returns an array of PSCustomObjects, one per service principal with Graph permissions.
### Each object contains:
### PrincipalId (String)
###     The Azure AD service principal object ID (GUID)
###     Example: "12345678-1234-1234-1234-123456789012"
### PrincipalName (String)
###     The display name of the application/service principal
###     Example: "Contoso HR Application"
### AppRoleCount (Int32)
###     Total number of Microsoft Graph permissions assigned to this principal
###     Example: 25
### AppRoles (Array)
###     Array of permission objects, each containing:
###     - appRoleId (String): The GUID identifier of the permission
###     - FriendlyName (String): Human-readable permission name (e.g., "User.Read.All", "Mail.Send")
###     - PermissionType (String): Classification - "Application", "DelegatedWork", or "Unknown"
###     - resourceDisplayName (String): The resource name, typically "Microsoft Graph"
### Special Cases:
### - Returns empty array if no applications have Graph permissions
### - Throws error if connection to Graph fails or insufficient permissions
## NOTES
Prerequisites:
- Must be connected to Microsoft Graph using Connect-EntraService with GraphBeta service
- Requires the following Microsoft Graph permissions:
  * Application.Read.All (to read service principals)
  * AppRoleAssignment.Read.All (to read app role assignments)
  * Directory.Read.All (recommended for complete data)
- Beta endpoint access required (function uses GraphBeta service)

Authentication:
The function requires prior authentication via Connect-EntraService.
Example:

Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret -Service "GraphBeta"

Or for interactive authentication:
Connect-EntraService -Service "GraphBeta"

Performance Considerations:
- Uses automatic pagination via Invoke-EntraRequest (handles large result sets)
- Uses explicit memory management with garbage collection
- Processing time scales with number of service principals (typically 30-120 seconds for large tenants)
- Can efficiently handle thousands of assignments

Memory Management:
The function implements several memory optimization techniques:
- Uses $select to only retrieve needed properties from Graph API
- Explicitly nulls large objects after use ($graphServicePrincipal = $null)
- Calls \[System.GC\]::Collect() at strategic points to free memory
- Consolidates lookup tables to reduce duplication
- Streams results rather than holding everything in memory
- Recommended for enterprise environments with many applications

Permission Type Classification:
- **Application**: App-only permissions that don't require user context
  Examples: User.Read.All, Mail.Read (when used by daemon apps)
- **DelegatedWork**: Permissions that require a signed-in user context
  Examples: User.Read, Mail.Read (when used by interactive apps)
- **Unknown**: Permission ID could not be resolved in lookup table
  This typically indicates a deprecated or custom permission

Microsoft Graph Service Principal:
The function specifically queries assignments for the Microsoft Graph service principal:
- AppId: 00000003-0000-0000-c000-000000000000
- This is the well-known application ID for Microsoft Graph
- Does not include assignments to other resource providers (e.g., SharePoint, Exchange)

API Calls Made:
1.
GET /servicePrincipals(appId='00000003-0000-0000-c000-000000000000')?$select=appRoles,publishedPermissionScopes,resourceSpecificApplicationPermissions
   - Retrieves Graph service principal with all permission definitions
2.
GET /servicePrincipals(appId='00000003-0000-0000-c000-000000000000')/appRoleAssignedTo?$select=appRoleId,principalId,principalDisplayName,resourceDisplayName
   - Retrieves all app role assignments with optimized query (automatically paginated)

Output Optimization:
The function returns streamlined objects containing only essential information:
- Reduces memory footprint compared to raw Graph API responses
- Optimized for pipeline operations and filtering
- Suitable for large-scale analysis and reporting
- Can be easily exported to CSV, JSON, or XML

Verbose Logging:
Use -Verbose to see detailed progress information:
- Service principal retrieval
- Number of assignments retrieved
- Lookup table construction progress
- Permission enrichment steps
- Final principal count

Common Use Cases:
1.
**Security Audits**: Identify over-privileged applications
2.
**Compliance Reporting**: Document permission assignments for auditors
3.
**Permission Inventory**: Baseline of current state before changes
4.
**Change Tracking**: Monitor permission grants over time
5.
**License Planning**: Understand Graph API feature usage
6.
**Incident Response**: Quickly identify which apps have sensitive permissions
7.
**Cleanup Projects**: Find candidates for permission removal

Error Handling:
- Throws error if Graph API connection fails
- Throws error if insufficient permissions to query
- All errors include detailed exception messages
- Use try/catch blocks for automation scenarios

Troubleshooting:

If "Insufficient privileges" error:
- Verify authentication with correct permissions
- Ensure Application.Read.All and AppRoleAssignment.Read.All are granted
- Check if admin consent has been provided for application permissions

If slow performance:
- Normal for large tenants (10,000+ assignments can take 2-3 minutes)
- Network latency affects pagination speed
- Consider running during off-peak hours for very large tenants

If memory errors:
- Increase PowerShell memory limits
- Close other memory-intensive applications
- Run on a machine with more available RAM

If empty results:
- Verify applications actually have Graph permissions assigned
- Check if connected to correct tenant
- Ensure using GraphBeta service (not GraphV1)

Best Practices:
- Always use -Verbose for long-running operations in production
- Save results with Export-Clixml for later analysis
- Implement error handling in automation scripts
- Schedule during off-peak hours for large tenants
- Archive results periodically for change tracking
- Combine with Get-PermissionAnalysis for comprehensive reviews

Related Cmdlets:
- Connect-EntraService: Authenticate to Microsoft Graph
- Get-PermissionAnalysis: Analyze if assigned permissions are actually needed
- Get-AppActivityData: Get API activity to determine permission usage
- Export-PermissionAnalysisReport: Generate HTML reports

## RELATED LINKS

[https://learn.microsoft.com/en-us/graph/permissions-reference](https://learn.microsoft.com/en-us/graph/permissions-reference)

[https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Get-AppRoleAssignment.html](https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Get-AppRoleAssignment.html)

