---
external help file: LeastPrivilegedMSGraph-help.xml
Module Name: LeastPrivilegedMSGraph
online version:
schema: 2.0.0
---

# Export-PermissionAnalysisReport

## SYNOPSIS
Generates an interactive HTML report for Microsoft Graph permission analysis.

## SYNTAX

```
Export-PermissionAnalysisReport [-AppData] <Array> [[-OutputPath] <String>] [[-ReportTitle] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function creates a comprehensive, interactive HTML report that visualizes permission analysis
results for Microsoft Graph applications.
The report includes statistics, filtering capabilities,
and detailed views of each application's permissions, activities, and throttling information.

The generated report features:
- Dark/light mode toggle
- Interactive data tables with sorting and filtering
- Permission status indicators (optimal, excess, unmatched)
- Throttling statistics and severity badges
- Detailed modal views for each application
- CSV export functionality
- Responsive design with Tailwind CSS

The function accepts application data via pipeline or parameter, processes it into JSON format,
and embeds it into an HTML template with dynamic JavaScript for interactivity.

## EXAMPLES

### EXAMPLE 1
```
$results | Export-PermissionAnalysisReport -OutputPath "C:\Reports\GraphPermissions.html"
```

Generates a report from pipeline input and saves it to the specified location.

### EXAMPLE 2
```
Export-PermissionAnalysisReport -AppData $analysisResults -ReportTitle "Production Apps - Q4 2024"
```

Creates a report with a custom title using the default output path.

### EXAMPLE 3
```
Get-MgServicePrincipal | Where-Object { $_.AppId -in $targetApps } |
    ForEach-Object { Analyze-AppPermissions $_ } |
    Export-PermissionAnalysisReport -OutputPath ".\Reports\$(Get-Date -Format 'yyyyMMdd')_Report.html"
```

Pipelines multiple applications through analysis and generates a timestamped report.

### EXAMPLE 4
```
$report = Export-PermissionAnalysisReport -AppData $data -OutputPath "report.html"
Start-Process $report
```

Generates the report and immediately opens it in the default browser.

## PARAMETERS

### -AppData
An array of application permission analysis objects.
Each object should contain:
- PrincipalName: The application name
- PrincipalId: The application/service principal ID
- CurrentPermissions: Array of currently assigned permissions
- OptimalPermissions: Array of optimal permission objects with Permission and ActivitiesCovered
- ExcessPermissions: Array of permissions that are not needed
- RequiredPermissions: Array of permissions needed but not currently assigned
- Activity: Array of API activity objects with Method and Uri properties
- UnmatchedActivities: Array of activities that couldn't be matched
- MatchedAllActivity: Boolean indicating if all activities were matched
- AppRoleCount: Total number of app roles assigned
- ThrottlingStats: Object containing throttling information (optional)

This parameter accepts pipeline input.

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

### -OutputPath
The file path where the HTML report will be saved.
Default: ".\PermissionAnalysisReport.html"

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: .\PermissionAnalysisReport.html
Accept pipeline input: False
Accept wildcard characters: False
```

### -ReportTitle
The title displayed in the report header and browser tab.
Default: "Microsoft Graph Permission Analysis Report"

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Microsoft Graph Permission Analysis Report
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

### String
### Returns the full path to the generated HTML report file.
## NOTES
Template Requirements:
- The function requires a base HTML template file located at "Private\base.html"
- The template uses placeholder blocks: {% block app_data %}, {% block title %}, {% block generated_on %}

JSON Processing:
- Application data is converted to JSON with depth 10 to preserve nested structures
- Special characters are escaped for JavaScript embedding
- Data is compressed to reduce file size

Browser Compatibility:
- Modern browsers (Chrome, Firefox, Edge, Safari) are recommended
- JavaScript must be enabled for full functionality
- Works offline once generated

This function uses Write-Debug for processing information and for success messages.

## RELATED LINKS
