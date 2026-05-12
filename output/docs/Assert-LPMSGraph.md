---
external help file: LeastPrivilegedMSGraph-help.xml
Module Name: LeastPrivilegedMSGraph
online version: https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Assert-LPMSGraph.html
schema: 2.0.0
---

# Assert-LPMSGraph

## SYNOPSIS
Validates all prerequisites and requirements for using the LeastPrivilegedMSGraph module.

## SYNTAX

```
Assert-LPMSGraph [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Assert-LPMSGraph function performs a comprehensive validation of all prerequisites required
to successfully use the LeastPrivilegedMSGraph module.
It checks multiple components including:

- Entra Service Connectivity: Verifies authentication to required services (LogAnalytics, Graph, Azure)
- Azure AD Premium License: Confirms that Microsoft Entra ID P1 or higher license is available
- Diagnostic Settings: Validates that MicrosoftGraphActivityLogs diagnostic settings are configured
- Log Analytics Access: Tests workspace access and verifies MicrosoftGraphActivityLogs data availability
- Microsoft Graph API Permissions: Confirms sufficient permissions to read applications

The function returns a detailed result object containing the overall status, individual check results,
tenant ID, and timestamp.
Each check includes a name, status (Passed/Failed), descriptive message,
and any error details encountered.

This function is useful for troubleshooting setup issues and confirming that the environment is
properly configured before performing permission analysis operations.

## EXAMPLES

### EXAMPLE 1
```
Assert-LPMSGraph
```

Runs all prerequisite checks and returns a detailed validation report.

### EXAMPLE 2
```
$result = Assert-LPMSGraph
PS C:\> $result.Checks | Where-Object Status -eq 'Failed'
```

Stores the validation result and filters to show only failed checks.

### EXAMPLE 3
```
Assert-LPMSGraph | Select-Object -ExpandProperty Checks | Format-Table Name, Status, Message -AutoSize
```

Displays all validation checks in a formatted table showing name, status, and message.

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
### - OverallStatus: String indicating "Passed" or "Failed"
### - Checks: Array of check result objects, each containing Name, Status, Message, and Error properties
### - TenantId: The current tenant ID from the authentication token
### - Timestamp: UTC timestamp when the validation was performed
## NOTES
Prerequisites:
- Must be connected to Entra services using Connect-EntraService
- Requires access to Azure AD tenant with appropriate permissions
- Requires Azure AD Premium P1 or higher license for activity logging

This function does not modify any settings or configurations.
It only performs read-only validation checks.

## RELATED LINKS

[https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Assert-LPMSGraph.html](https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Assert-LPMSGraph.html)

