---
external help file: LeastPrivilegedMSGraph-help.xml
Module Name: LeastPrivilegedMSGraph
online version:
schema: 2.0.0
---

# Get-AppRoleAssignment

## SYNOPSIS
Retrieves Microsoft Graph app role assignments for all applications.

## SYNTAX

```
Get-AppRoleAssignment [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function queries Microsoft Graph to get all app role assignments for Microsoft Graph API permissions.
It retrieves the assignments, translates permission IDs to friendly names, and groups them by principal
(service principal/application).

The function performs the following operations:
1.
Retrieves the Microsoft Graph service principal information
2.
Fetches all app role assignments with automatic pagination
3.
Builds a lookup table mapping permission IDs to friendly names
4.
Enriches assignments with permission names and types (Application/Delegated)
5.
Groups assignments by principal for easy analysis
6.
Returns streamlined objects with essential information

Permission types included:
- Application permissions (appRoles)
- Resource-specific application permissions
- Delegated work permissions (publishedPermissionScopes)

The function uses memory optimization techniques including explicit garbage collection
to handle large result sets efficiently.

## EXAMPLES

### EXAMPLE 1
```
Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret -Service "GraphBeta"
$assignments = Get-AppRoleAssignment
```

Retrieves all app role assignments for Microsoft Graph after authenticating.
Output shows all applications and their assigned permissions.

### EXAMPLE 2
```
$assignments = Get-AppRoleAssignment -Verbose
$overPrivilegedApps = $assignments | Where-Object { $_.AppRoleCount -gt 50 }
$overPrivilegedApps | Format-Table PrincipalName, AppRoleCount
```

Finds applications with more than 50 assigned permissions and displays them,
using verbose output to track progress.

### EXAMPLE 3
```
$assignments = Get-AppRoleAssignment
$appPerms = $assignments | ForEach-Object {
    $app = $_
    $app.AppRoles | Where-Object { $_.PermissionType -eq 'Application' } | ForEach-Object {
        [PSCustomObject]@{
            AppName = $app.PrincipalName
            Permission = $_.FriendlyName
        }
    }
}
$appPerms | Export-Csv -Path "application-permissions.csv" -NoTypeInformation
```

Extracts all application-scoped permissions across all apps and exports to CSV.

### EXAMPLE 4
```
$assignments = Get-AppRoleAssignment
$criticalPerms = @('Directory.ReadWrite.All', 'RoleManagement.ReadWrite.Directory', 'Application.ReadWrite.All')
$assignments | Where-Object {
    ($_.AppRoles.FriendlyName | Where-Object { $_ -in $criticalPerms }).Count -gt 0
} | Select-Object PrincipalName, @{N='CriticalPerms';E={
    ($_.AppRoles | Where-Object { $_.FriendlyName -in $criticalPerms }).FriendlyName -join ', '
}}
```

Identifies applications with high-privilege permissions and shows which ones they have.

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

### Array
### Returns an array of PSCustomObjects with the following properties:
### - PrincipalId: The service principal ID (object ID) of the application
### - PrincipalName: The display name of the application/service principal
### - AppRoleCount: Total number of app roles (permissions) assigned to this principal
### - AppRoles: Array of role objects, each containing:
###   - appRoleId: The GUID of the permission
###   - FriendlyName: The permission name (e.g., "User.Read.All", "Mail.Send")
###   - PermissionType: Either "Application", "DelegatedWork", or "Unknown"
###   - resourceDisplayName: The resource the permission applies to (typically "Microsoft Graph")
## NOTES
Prerequisites:
- Must be connected to Microsoft Graph using Connect-EntraService
- Requires permission to read service principals and app role assignments
- Beta endpoint access required (uses GraphBeta service)

Performance Considerations:
- Uses automatic pagination via Invoke-EntraRequest
- Implements memory optimization with explicit garbage collection
- Can handle thousands of assignments efficiently
- Processing time scales with number of principals and assignments

Memory Management:
- Explicitly nulls large objects after use
- Calls System.GC.Collect() to free memory between operations
- Recommended for environments with many applications

Permission Type Classification:
- Application: App-only permissions (no user context)
- DelegatedWork: Permissions that require user context
- Unknown: Could not determine type from lookup

This function uses Write-Verbose for progress updates and Write-Error for exception handling.
All Graph API calls use Invoke-EntraRequest which handles authentication and retry logic.

## RELATED LINKS
