---
external help file: LeastPrivilegedMSGraph-help.xml
Module Name: LeastPrivilegedMSGraph
online version:
schema: 2.0.0
---

# Get-PermissionAnalysis

## SYNOPSIS
Analyzes application permissions against actual API activity to identify optimal permission sets.

## SYNTAX

```
Get-PermissionAnalysis [-AppData] <Array> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function performs comprehensive permission analysis by comparing an application's current
Microsoft Graph permissions against its actual API activity patterns.
It determines the least
privileged permission set needed and identifies excess or missing permissions.

The function performs the following operations:
1.
Loads Microsoft Graph permission maps (v1.0 and beta endpoints)
2.
Analyzes each application's API activity to find required permissions
3.
Calculates the optimal (minimal) permission set using a greedy algorithm
4.
Compares current permissions against optimal permissions
5.
Identifies excess permissions that aren't needed
6.
Identifies missing permissions that should be added
7.
Tracks unmatched activities that couldn't be mapped to permissions

This analysis is critical for implementing least privilege access principles and reducing
security risks from over-privileged applications.

## EXAMPLES

### EXAMPLE 1
```
$apps = Get-MgServicePrincipal -All
$appsWithActivity = $apps | Add-AppActivityData -WorkspaceId $workspaceId -Days 30
$analysis = $appsWithActivity | Get-PermissionAnalysis
```

Performs end-to-end analysis: retrieves apps, adds activity data, and analyzes permissions.

### EXAMPLE 2
```
$analysis = Get-PermissionAnalysis -AppData $enrichedApps -Verbose
$overPrivileged = $analysis | Where-Object { $_.ExcessPermissions.Count -gt 10 }
$overPrivileged | Select-Object PrincipalName, @{N='Excess';E={$_.ExcessPermissions.Count}},
                               @{N='Current';E={$_.CurrentPermissions.Count}},
                               @{N='Optimal';E={$_.OptimalPermissions.Count}}
```

Identifies applications with more than 10 excess permissions and displays comparison metrics.

### EXAMPLE 3
```
$analysis = Get-PermissionAnalysis -AppData $apps
$unmatched = $analysis | Where-Object { -not $_.MatchedAllActivity }
```

foreach ($app in $unmatched) {
    "\`n$($app.PrincipalName) has unmatched activities:" -ForegroundColor Yellow
    $app.UnmatchedActivities | ForEach-Object {
        "  $($_.Method) $($_.Path)" -ForegroundColor Gray
    }
}

Identifies applications with activities that couldn't be mapped to known permissions.

### EXAMPLE 4
```
$analysis = Get-PermissionAnalysis -AppData $apps
$needsUpdate = $analysis | Where-Object {
    $_.ExcessPermissions.Count -gt 0 -or $_.RequiredPermissions.Count -gt 0
}
```

$needsUpdate | ForEach-Object {
    \[PSCustomObject\]@{
        Application = $_.PrincipalName
        Status = if ($_.ExcessPermissions.Count -gt 0 -and $_.RequiredPermissions.Count -eq 0) {
            "Remove $($_.ExcessPermissions.Count) permissions"
        } elseif ($_.RequiredPermissions.Count -gt 0 -and $_.ExcessPermissions.Count -eq 0) {
            "Add $($_.RequiredPermissions.Count) permissions"
        } else {
            "Update ($($_.ExcessPermissions.Count) excess, $($_.RequiredPermissions.Count) missing)"
        }
        ExcessPerms = $_.ExcessPermissions -join ', '
        MissingPerms = $_.RequiredPermissions -join ', '
    }
} | Format-Table -AutoSize

Generates an actionable report showing which applications need permission updates.

## PARAMETERS

### -AppData
An array of application objects to analyze.
Each object must contain:
- PrincipalId: The service principal ID
- PrincipalName: The application display name
- Activity: Array of API activity objects with Method and Uri properties
- AppRoles: Array of current app role assignments with FriendlyName property

This parameter accepts pipeline input, enabling batch processing of multiple applications.

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

### Array
### Returns the input application objects enriched with the following additional properties:
### - ActivityPermissions: Detailed permission mappings for each activity
### - OptimalPermissions: Array of optimal permission objects with Permission, ScopeType,
###   IsLeastPrivilege, and ActivitiesCovered properties
### - UnmatchedActivities: Array of activities that couldn't be matched to known endpoints
### - CurrentPermissions: Array of currently assigned permission names
### - ExcessPermissions: Array of permissions assigned but not needed based on activity
### - RequiredPermissions: Array of permissions needed but not currently assigned
### - MatchedAllActivity: Boolean indicating if all activities were successfully matched
## NOTES
Prerequisites:
- Permission map files must exist in the module's data folder:
  * data\permissions-v1.0.json
  * data\permissions-beta.json
- Input applications must have Activity property populated (use Add-AppActivityData)
- Input applications must have AppRoles property populated (use Get-AppRoleAssignment)

Permission Maps:
- Contains endpoint-to-permission mappings for Microsoft Graph APIs
- Includes both v1.0 and beta API versions
- Maps HTTP methods to required permissions
- Indicates least privileged permissions with flags

Analysis Algorithm:
- Uses greedy set cover algorithm to minimize permission count
- Prioritizes permissions marked as "least privileged"
- Ensures all matched activities are covered by selected permissions
- Tolerates unmatched activities (new or undocumented APIs)

Performance Considerations:
- Permission maps are loaded once in the begin block
- Processing time scales linearly with number of applications
- Each application is analyzed independently
- Suitable for batch processing of many applications

Output Properties:
- All original app properties are preserved
- New analysis properties are added via Add-Member
- Use -Force to overwrite existing properties

This function uses Write-Debug for detailed processing information and requires
Find-LeastPrivilegedPermission and Get-OptimalPermissionSet helper functions.

## RELATED LINKS
