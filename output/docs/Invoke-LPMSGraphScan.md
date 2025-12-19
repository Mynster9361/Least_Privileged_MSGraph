---
external help file: LeastPrivilegedMSGraph-help.xml
Module Name: LeastPrivilegedMSGraph
online version: https://docs.microsoft.com/en-us/azure/azure-monitor/logs/api/overview
schema: 2.0.0
---

# Invoke-LPMSGraphScan

## SYNOPSIS
Executes a complete Microsoft Graph least privilege analysis workflow from data collection to report generation.

## SYNTAX

### ByWorkspaceId
```
Invoke-LPMSGraphScan -WorkspaceId <String> [-ExcludeThrottleData] [-Days <Int32>] [-ThrottleLimit <Int32>]
 [-MaxActivityEntries <Int32>] [-OutputPath <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### ByWorkspaceDetails
```
Invoke-LPMSGraphScan -subId <String> -rgName <String> -workspaceName <String> [-ExcludeThrottleData]
 [-Days <Int32>] [-ThrottleLimit <Int32>] [-MaxActivityEntries <Int32>] [-OutputPath <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function orchestrates the entire least privileged permission analysis process by executing
a comprehensive workflow that combines data retrieval, activity analysis, and report generation
into a single streamlined operation.

The workflow performs the following steps in sequence:
1.
**Retrieves app role assignments** - Gets all applications with Microsoft Graph permissions
2.
**Collects activity data** - Queries Log Analytics for actual API usage over specified time period
3.
**Gathers throttling data** (optional) - Identifies apps experiencing rate limiting
4.
**Analyzes permissions** - Compares assigned vs.
used permissions to identify least privileged set
5.
**Generates HTML report** - Creates comprehensive visualization with recommendations

This function is designed as a "one-command" solution for permission audits, eliminating
the need to manually chain multiple commands together.
It handles the complete data flow
through the pipeline while providing comprehensive logging and error handling.

Use Cases:
- Quick permission audits without manual workflow orchestration
- Scheduled/automated compliance reporting
- Initial assessment of tenant permission posture
- Regular permission optimization reviews
- Security team dashboards and reporting

Requirements:
- Active connection to Microsoft Graph with sufficient permissions
- Azure Log Analytics workspace with Microsoft Graph diagnostic logs enabled
- Appropriate Azure permissions to query Log Analytics data

## EXAMPLES

### EXAMPLE 1
```
Initialize-LogAnalyticsApi
Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret -Service "GraphBeta", "LogAnalytics"
Invoke-LPMSGraphScan -WorkspaceId "123456-workspace-id-456"
```

Description:
Executes a complete scan using all default parameters:
- Analyzes last 30 days of activity
- Includes throttling data
- Uses 20 parallel workers
- Retrieves up to 100,000 activity entries per app
- Generates report.html in the current directory

### EXAMPLE 2
```
Invoke-LPMSGraphScan -subId "12345678-1234-1234-1234-123456789012" -rgName "rg-monitoring" -workspaceName "law-graphlogs" -Days 90 -OutputPath "C:\Reports\Q4-audit.html" -Verbose
```

Description:
Executes scan by specifying workspace details separately:
- Constructs full workspace resource ID from components
- Analyzes 90 days of historical activity
- Includes verbose logging for monitoring
- Generates report at specified path

### EXAMPLE 3
```
Invoke-LPMSGraphScan -WorkspaceId $workspaceId -ExcludeThrottleData -Days 7 -ThrottleLimit 10 -OutputPath ".\quick-check.html"
```

Description:
Executes a quick permission check:
- Only analyzes last 7 days
- Skips throttling data collection for faster execution
- Uses conservative parallelization (10 workers)
- Suitable for rapid assessments or testing

### EXAMPLE 4
```
$params = @{
    WorkspaceId = "/subscriptions/sub-123/resourceGroups/rg-logs/providers/Microsoft.OperationalInsights/workspaces/law-graph"
    Days = 60
    ThrottleLimit = 30
    MaxActivityEntries = 200000
    OutputPath = ".\enterprise-audit.html"
}
Invoke-LPMSGraphScan @params -Verbose
```

Description:
Enterprise-scale scan with optimized parameters:
- 60-day analysis period for comprehensive coverage
- Higher parallelization (30 workers) for faster processing
- Increased activity entry limit for very active applications
- Verbose output for monitoring large-scale execution

## PARAMETERS

### -WorkspaceId
The full Azure Resource Manager resource ID of the Log Analytics workspace.
Used with the 'ByWorkspaceId' parameter set.

Format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/{workspaceName}

Example: "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-graphlogs"

Mutually exclusive with subId, rgName, and workspaceName parameters.

```yaml
Type: String
Parameter Sets: ByWorkspaceId
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -subId
Azure subscription ID (GUID) where the Log Analytics workspace is located.
Used with the 'ByWorkspaceDetails' parameter set when you want to specify workspace details separately.

Example: "12345678-1234-1234-1234-123456789012"

Required together with rgName and workspaceName parameters.

```yaml
Type: String
Parameter Sets: ByWorkspaceDetails
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -rgName
Azure resource group name where the Log Analytics workspace is located.
Used with the 'ByWorkspaceDetails' parameter set.

Example: "rg-monitoring"

Required together with subId and workspaceName parameters.

```yaml
Type: String
Parameter Sets: ByWorkspaceDetails
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -workspaceName
Log Analytics workspace name.
Used with the 'ByWorkspaceDetails' parameter set.

Example: "law-graphlogs"

Required together with subId and rgName parameters.

```yaml
Type: String
Parameter Sets: ByWorkspaceDetails
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeThrottleData
Switch parameter to skip the throttling data collection step.
Default: $false (throttling data IS collected by default)

Use this switch when:
- You want faster execution and don't need throttling insights
- Your workspace doesn't have throttling data available
- You're only interested in permission optimization, not performance issues

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

### -Days
The number of days of historical activity to analyze, counting back from the current date.
Default: 30 days

Recommended values:
- **7**: Quick analysis, recent activity only
- **30**: Balanced view (default) - captures monthly patterns
- **90**: Comprehensive analysis including seasonal variations

Note: Longer periods provide better coverage but increase query time and data processing.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 30
Accept pipeline input: False
Accept wildcard characters: False
```

### -ThrottleLimit
The maximum number of concurrent runspaces to use for parallel processing of applications.
Default: 20
Valid range: 1-50

Recommended values:
- **10**: Conservative for rate-limited environments
- **20**: Balanced performance (default)
- **30**: Aggressive for high-throughput scenarios with many applications

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 20
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxActivityEntries
The maximum number of activity log entries to retrieve per application from Log Analytics.
Default: 100000
Valid range: 1-500000 (Log Analytics limit)

This prevents excessive data retrieval for very active applications while still
capturing comprehensive usage patterns.
Most applications will have fewer entries
than this limit for typical analysis periods.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 100000
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutputPath
The file path where the HTML report should be generated.
Default: ".\report.html" (current directory)

Supports absolute and relative paths.
The directory will be created if it doesn't exist.

Example: "C:\Reports\GraphPermissions\audit-2024-12.html"

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: .\report.html
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

### None
### This function generates an HTML report file at the specified OutputPath.
### The report contains visualizations and recommendations for permission optimization.
### Progress and status information is written to the verbose and information streams.
## NOTES
This function requires:
- EntraAuth module for Graph authentication
- PSFramework module for parallel processing
- Active Graph connection with appropriate permissions
- Log Analytics workspace with Graph diagnostic logs

Error Handling:
- Returns early if no app role assignments are found
- Propagates errors from individual workflow steps
- Provides detailed error messages for troubleshooting

## RELATED LINKS
