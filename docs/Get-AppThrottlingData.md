---
external help file: LeastPrivilegedMSGraph-help.xml
Module Name: LeastPrivilegedMSGraph
online version:
schema: 2.0.0
---

# Get-AppThrottlingData

## SYNOPSIS
Enriches application data with throttling statistics from Azure Log Analytics.

## SYNTAX

```
Get-AppThrottlingData [-AppData] <Array> [-WorkspaceId] <String> [[-Days] <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function queries Azure Log Analytics to retrieve Microsoft Graph API throttling statistics
for each application over a specified time period.
It gets comprehensive throttling metrics as
a new property to each application object, enabling analysis of API rate limiting impacts.

The function processes all applications efficiently by:
1.
Fetching all throttling statistics in a single batch query
2.
Creating an indexed lookup table for fast matching
3.
Matching applications to their statistics using ServicePrincipalId
4.
Getting zeroed statistics for applications without activity

Throttling metrics include:
- Total requests and success/error counts
- 429 (Too Many Requests) error counts and throttle rates
- Overall error and success rates
- Throttling severity classification (0-4 scale)
- First and last occurrence timestamps
- Human-readable throttling status

This data is critical for identifying applications experiencing API rate limiting issues
and understanding their impact on application performance.

## EXAMPLES

### EXAMPLE 1
```
$apps = Get-MgServicePrincipal -Filter "appId eq '00000000-0000-0000-0000-000000000000'"
$enrichedApps = $apps | Get-AppThrottlingData -WorkspaceId "12345678-abcd-efgh-ijkl-123456789012"
```

Retrieves throttling statistics for a specific application over the default 30-day period.

### EXAMPLE 2
```
$allApps = Get-MgServicePrincipal -All
$appsWithThrottling = $allApps | Get-AppThrottlingData -WorkspaceId $workspaceId -Days 90
$criticalApps = $appsWithThrottling | Where-Object { $_.ThrottlingStats.ThrottlingSeverity -ge 3 }
```

Analyzes 90 days of data and identifies applications with Warning or Critical throttling severity.

### EXAMPLE 3
```
$apps | Get-AppThrottlingData -WorkspaceId $workspaceId -Days 7 -Verbose |
    Where-Object { $_.ThrottlingStats.Total429Errors -gt 100 } |
    Select-Object PrincipalName, @{N='429 Errors';E={$_.ThrottlingStats.Total429Errors}},
                  @{N='Throttle Rate';E={$_.ThrottlingStats.ThrottleRate}}
```

Finds applications with more than 100 throttling errors in the last 7 days and displays key metrics.

### EXAMPLE 4
```
$results = $apps | Get-AppThrottlingData -WorkspaceId $workspaceId -Days 30
$results | Where-Object { $_.ThrottlingStats.ThrottlingStatus -ne 'No Activity' } |
    Export-Csv -Path "throttling-report.csv" -NoTypeInformation
```

Exports throttling data for all active applications to a CSV file.

## PARAMETERS

### -AppData
An array of application objects to enrich with throttling data.
Each object should contain:
- PrincipalId: The service principal ID of the application (used for matching)
- PrincipalName: The application display name (for logging/progress)

This parameter accepts pipeline input, allowing you to pipe application objects directly
into the function.

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
The Azure Log Analytics workspace ID (GUID) where Microsoft Graph API activity logs are stored.
This workspace must contain MicrosoftGraphActivityLogs table with throttling information.

Example: "12345678-1234-1234-1234-123456789012"

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
The number of days of historical throttling data to retrieve, counting back from the current date.
Default: 30 days

Recommended values:
- 7 days: Recent throttling analysis
- 30 days: Standard monthly review
- 90 days: Comprehensive quarterly analysis

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
### Returns the input application objects enriched with a "ThrottlingStats" property containing:
### - TotalRequests: Total API requests made
### - SuccessfulRequests: Requests that succeeded (2xx responses)
### - Total429Errors: Number of throttling errors
### - TotalClientErrors: All 4xx errors (including 429)
### - TotalServerErrors: All 5xx errors
### - ThrottleRate: Percentage of requests that were throttled
### - ErrorRate: Percentage of all failed requests
### - SuccessRate: Percentage of successful requests
### - ThrottlingSeverity: Numeric severity (0=Normal, 1=Minimal, 2=Low, 3=Warning, 4=Critical)
### - ThrottlingStatus: Human-readable status description
### - FirstOccurrence: Timestamp of first request in period
### - LastOccurrence: Timestamp of last request in period
### Applications without activity receive zeroed statistics with "No Activity" status.
## NOTES
Prerequisites:
- Azure Log Analytics workspace with MicrosoftGraphActivityLogs enabled
- Appropriate permissions to query the Log Analytics workspace
- Get-AppThrottlingStat function must be available

Performance Considerations:
- Uses bulk query approach for better performance
- Processes all applications in a single Log Analytics query
- Creates indexed lookup table for O(1) matching
- Progress bar displays processing status

Throttling Severity Scale:
- 0 (Normal): No throttling or very minimal (\< 1%)
- 1 (Minimal): Low throttling (1-5%)
- 2 (Low): Noticeable throttling (5-10%)
- 3 (Warning): Significant throttling (10-25%)
- 4 (Critical): Severe throttling (\> 25%)

Matching Logic:
- Uses ServicePrincipalId (case-insensitive) for matching
- Applications without matches receive zeroed statistics
- Logs verbose information about match success/failure

This function uses Write-Debug for detailed processing information, Write-Verbose for
match status updates, and Write-Progress for visual feedback.

## RELATED LINKS
