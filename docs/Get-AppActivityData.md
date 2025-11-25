---
external help file: LeastPrivilegedMSGraph-help.xml
Module Name: LeastPrivilegedMSGraph
online version:
schema: 2.0.0
---

# Get-AppActivityData

## SYNOPSIS
Enriches application data with API activity information from Azure Log Analytics.

## SYNTAX

```
Get-AppActivityData [-AppData] <Array> [-WorkspaceId] <String> [[-Days] <Int32>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function queries Azure Log Analytics workspace to retrieve Microsoft Graph API activity
for each application over a specified time period.
It gets the activity data as a new property
to each application object, enabling analysis of what API calls each application has made.

The function processes applications in batches, displaying progress information, and handles
errors gracefully by continuing to process remaining applications even if some queries fail.

Activity data includes:
- HTTP methods used (GET, POST, PUT, PATCH, DELETE)
- API endpoints accessed
- Request timestamps
- Response codes

This data is essential for determining the least privileged permissions needed, as it shows
what Graph API operations the application actually performs.

## EXAMPLES

### EXAMPLE 1
```
$apps = Get-MgServicePrincipal -Filter "appId eq '00000000-0000-0000-0000-000000000000'"
$enrichedApps = $apps | Get-AppActivityData -WorkspaceId "12345678-abcd-efgh-ijkl-123456789012"
```

Retrieves activity for a specific application over the default 30-day period.

### EXAMPLE 2
```
$allApps = Get-MgServicePrincipal -All
$appsWithActivity = $allApps | Get-AppActivityData -WorkspaceId $workspaceId -Days 90
$activeApps = $appsWithActivity | Where-Object { $_.Activity.Count -gt 0 }
```

Analyzes 90 days of activity for all service principals and filters to only those with activity.

### EXAMPLE 3
```
$apps = Get-Content .\apps.json | ConvertFrom-Json
$results = Get-AppActivityData -AppData $apps -WorkspaceId $workspaceId -Days 7 -Verbose
$results | Export-Clixml .\enriched-apps.xml
```

Loads applications from JSON, gets 7 days of activity with verbose output, and saves results.

### EXAMPLE 4
```
$criticalApps = Get-MgServicePrincipal -Filter "tags/any(t:t eq 'Critical')"
$criticalApps | Get-AppActivityData -WorkspaceId $workspaceId -Days 30 |
    ForEach-Object {
        if ($_.Activity.Count -eq 0) {
            Write-Warning "$($_.PrincipalName) has no recent activity!"
        }
    }
```

Monitors critical applications for activity and alerts if any have been inactive.

## PARAMETERS

### -AppData
An array of application objects to enrich with activity data.
Each object should contain
at minimum:
- PrincipalId: The service principal ID of the application
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
The Azure Log Analytics workspace ID (GUID) where Microsoft Graph API sign-in logs are stored.
This workspace must contain MicrosoftGraphActivityLogs table with application activity data.

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
The number of days of historical activity to retrieve, counting back from the current date.
Default: 30 days

Recommended values:
- 7 days: Quick analysis for active applications
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
### Returns the input application objects enriched with an "Activity" property containing an
### array of API activity records. If no activity is found or an error occurs, the Activity
### property will be an empty array.
## NOTES
Prerequisites:
- Azure Log Analytics workspace with MicrosoftGraphActivityLogs enabled
- Appropriate permissions to query the Log Analytics workspace
- Get-AppActivityFromLog function must be available

Performance Considerations:
- Processing time scales linearly with the number of applications
- Each application requires a separate Log Analytics query
- Large result sets may take several minutes to complete
- Progress bar updates after each application is processed

Error Handling:
- Failures for individual applications are logged as warnings
- Processing continues even if some queries fail
- Failed applications receive an empty Activity array

This function uses Write-Debug for detailed processing information, Write-Verbose for
progress updates, and Write-Progress for visual feedback during long operations.

## RELATED LINKS
