---
external help file: LeastPrivilegedMSGraph-help.xml
Module Name: LeastPrivilegedMSGraph
online version: https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Get-LPMSPermissionAnalysis.html
schema: 2.0.0
---

# Get-LPMSPermissionAnalysis

## SYNOPSIS
Enriches application data with permission analysis using MSGraphPermissions module.

## SYNTAX

```
Get-LPMSPermissionAnalysis [-AppData] <Array> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function analyzes application permissions against actual API usage to determine
the least privileged permission set required.
It uses the Find-GraphLeastPrivilege
cmdlet from the MSGraphPermissions module to perform accurate permission lookups.

The permission scope (Application vs Delegated) is determined automatically from
the activity data - each activity carries a Scheme property set by the Log Analytics
query based on whether a ServicePrincipalId was present (Application) or not (Delegated).

The function processes each application's activity and:
1.
Extracts API version and path from each activity URI
2.
Uses the activity's Scheme to query Find-GraphLeastPrivilege for the correct scope
3.
Calculates optimal permission set using greedy set cover algorithm
4.
Identifies excess permissions (granted but not needed) with scope-aware comparison
5.
Identifies missing permissions (needed but not granted)

Permission Analysis includes:
- **Activity Permissions**: Matched permissions for each API activity
- **Optimal Permissions**: Minimum set covering all activities
- **Current Permissions**: Currently granted application permissions
- **Excess Permissions**: Granted but unused permissions
- **Required Permissions**: Needed but missing permissions
- **Unmatched Activities**: API calls without permission matches

## EXAMPLES

### EXAMPLE 1
```
$apps = Get-LPMSAppRoleAssignment | Get-LPMSAppActivityData -WorkspaceId $workspaceId -Days 30
$analysis = $apps | Get-LPMSPermissionAnalysis
```

Description:
Analyzes permissions for all applications based on 30 days of activity.
The Scheme (Application/Delegated) is automatically determined from the activity data.

### EXAMPLE 2
```
$analysis = $apps | Get-LPMSPermissionAnalysis
$analysis | Where-Object { $_.ExcessPermissions.Count -gt 0 } |
    Select-Object PrincipalName, @{N='Excess';E={$_.ExcessPermissions -join ', '}}
```

Description:
Identifies applications with excessive permissions that can be removed.

### EXAMPLE 3
```
$analysis = $apps | Get-LPMSPermissionAnalysis
$analysis | Where-Object { -not $_.MatchedAllActivity } |
    ForEach-Object {
        Write-Warning "$($_.PrincipalName) has unmatched activities"
        $_.UnmatchedActivities | Format-Table Method, Path
    }
```

Description:
Finds applications with API activities that couldn't be matched to permissions.

## PARAMETERS

### -AppData
Array of application objects with Activity and AppRoles properties.
Typically from Get-LPMSAppRoleAssignment | Get-LPMSAppActivityData pipeline.

Required Properties:
- **PrincipalName** (String): Application display name
- **Activity** (Array): API activity objects with Uri, Method, and Scheme properties
- **AppRoles** (Array): Currently assigned Graph permissions

Example application object:
@{
    PrincipalName = "HR Application"
    PrincipalId = "12345678-1234-1234-1234-123456789012"
    Activity = @(@{Uri = "https://graph.microsoft.com/v1.0/users"; Method = "GET"; Scheme = "Application"})
    AppRoles = @(@{FriendlyName = "User.Read.All"; PermissionType = "Application"})
}

```yaml
Type: Array
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

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

### PSCustomObject[]
### Returns input objects enriched with permission analysis properties:
### - **ActivityPermissions**: Array of matched permissions per activity
### - **OptimalPermissions**: Minimum permission set covering all activities
### - **UnmatchedActivities**: Activities without permission matches
### - **CurrentPermissions**: Currently granted permissions
### - **ExcessPermissions**: Granted but unused permissions
### - **RequiredPermissions**: Needed but missing permissions
### - **MatchedAllActivity**: Boolean indicating if all activities were matched
## NOTES
Prerequisites:
- MSGraphPermissions module must be installed and imported
- Get-OptimalPermissionSet function must be available (private function dependency)
- PowerShell 5.1 or later
- Application objects must have Activity property populated with Scheme

Permission Matching:
- Uses Find-GraphLeastPrivilege from MSGraphPermissions module
- Extracts version (v1.0 or beta) from URI automatically
- Scheme (Application/Delegated) is determined from the activity data
- Handles both successful and unmatched activities gracefully

Performance:
- Calls Find-GraphLeastPrivilege once per unique activity (single scheme lookup)
- Efficient permission set calculation using greedy algorithm
- Typical processing: 1-5 seconds per application with 100-1000 activities

Limitations:
- Requires accurate activity data from Get-LPMSAppActivityData (with Scheme)
- Custom/preview APIs may not have permission mappings
- Unmatched activities don't fail the overall analysis

Best Practices:
- Collect sufficient activity data (30+ days recommended)
- Review unmatched activities manually
- Validate optimal permissions before applying changes
- Use -Verbose for detailed matching information
- Archive analysis results for compliance tracking

Related Cmdlets:
- Get-LPMSAppActivityData: Collect API activity from Log Analytics
- Get-OptimalPermissionSet: Calculate minimum permission set (internal)
- Find-GraphLeastPrivilege: MSGraphPermissions module cmdlet
- Export-LPMSPermissionAnalysisReport: Generate visual reports

## RELATED LINKS

[https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Get-LPMSPermissionAnalysis.html](https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Get-LPMSPermissionAnalysis.html)

[https://github.com/merill/MSGraphPermissions](https://github.com/merill/MSGraphPermissions)

