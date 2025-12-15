---
external help file: LeastPrivilegedMSGraph-help.xml
Module Name: LeastPrivilegedMSGraph
online version: https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Get-AppActivityData.html
schema: 2.0.0
---

# Get-AppActivityData

## SYNOPSIS
Enriches application data with API activity information from Azure Log Analytics.

## SYNTAX

```
Get-AppActivityData [-AppData] <Array> [-WorkspaceId] <String> [[-Days] <Int32>] [[-ThrottleLimit] <Int32>]
 [[-MaxActivityEntries] <Int32>] [-retainRawUri] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function queries Azure Log Analytics workspace to retrieve Microsoft Graph API activity
for each application over a specified time period using parallel runspace execution.

Uses PSFramework's Runspace Workflow for efficient parallel processing while maintaining
pipeline streaming capabilities.
Applications are processed through a queue-based workflow
with configurable parallelization.

Activity data includes:
- HTTP methods used (GET, POST, PUT, PATCH, DELETE, etc.)
- API endpoints accessed (normalized and tokenized for pattern matching)
- Unique method/URI combinations (deduplicated)
- Tokenized URIs with {id} placeholders for permission mapping

This data is essential for:
- Determining least privileged permissions based on actual API usage
- Identifying unused permissions that can be removed
- Understanding application behavior and API consumption patterns
- Auditing what Graph API operations applications perform
- Planning permission optimization initiatives

Key Features:
- Parallel processing using PSFramework runspaces (5-10x faster for large datasets)
- Pipeline streaming for memory efficiency
- Individual error handling (one failure doesn't stop processing)
- Verbose logging for monitoring
- Debug output for troubleshooting
- Progress tracking
- Returns enhanced objects with Activity property

## EXAMPLES

### EXAMPLE 1
```
$apps | Get-AppActivityData -WorkspaceId $workspaceId -Days 90 -ThrottleLimit 20 -Verbose
```

## PARAMETERS

### -AppData
An array of application objects to enrich with activity data.
Each object must contain:

Required Properties:
- **PrincipalId** (String): The Azure AD service principal object ID
- **PrincipalName** (String): The application display name (used for logging/progress)

Optional Properties:
- Any other properties are preserved and passed through
- Common properties: AppId, Tags, AppRoles, etc.

This parameter accepts pipeline input, allowing you to pipe application objects directly
from Get-MgServicePrincipal or other sources.

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

### -WorkspaceId
The Azure Log Analytics workspace ID (GUID) where Microsoft Graph activity logs are stored.
This workspace must contain the MicrosoftGraphActivityLogs table with diagnostic logging enabled.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Days
The number of days of historical activity to retrieve, counting back from the current date.
Default: 30 days

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 30
Accept pipeline input: False
Accept wildcard characters: False
```

### -ThrottleLimit
The maximum number of concurrent runspaces to use for parallel processing.
Default: 10

Recommended values:
- **5**: Conservative for rate-limited environments
- **10**: Balanced performance (default)
- **20**: Aggressive for high-throughput scenarios

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 10
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxActivityEntries
The maximum number of activity entries to retrieve per application from Log Analytics.
This limits the result set size to prevent excessive data retrieval and memory consumption.
Default: 100000

Recommended values:
- **30000**: Conservative, faster queries
- **100000**: Balanced (default)

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: 100000
Accept pipeline input: False
Accept wildcard characters: False
```

### -retainRawUri
Optional switch.
Returns cleaned but non-tokenized URIs when specified.
Default behavior tokenizes URIs by replacing IDs with {id} placeholders.
NOTE if you utilize this switch you will not be able to run a permission analysis on the endpoints

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
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

### System.Object
### Returns the input application objects enriched with an "Activity" property.
## NOTES
Prerequisites:
- PowerShell 5.1 or later
- PSFramework module
- EntraAuth module with active Log Analytics connection
- Azure Log Analytics workspace with MicrosoftGraphActivityLogs table enabled
- Must be authenticated via Connect-EntraService before calling this function

## RELATED LINKS

[https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Get-AppActivityData.html](https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Get-AppActivityData.html)

