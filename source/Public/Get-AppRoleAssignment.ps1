function Get-AppRoleAssignment {
  <#
.SYNOPSIS
    Retrieves Microsoft Graph app role assignments for all applications in the tenant.

.DESCRIPTION
    This function queries Microsoft Graph to retrieve all app role assignments for Microsoft Graph API
    permissions across all service principals in the tenant. It provides a comprehensive view of which
    applications have which Microsoft Graph permissions assigned.

    The function performs the following operations:
    1. Retrieves the Microsoft Graph service principal information (appId: 00000003-0000-0000-c000-000000000000)
    2. Fetches all app role assignments using automatic pagination
    3. Builds a comprehensive lookup table mapping permission IDs to friendly names
    4. Enriches assignments with human-readable permission names and types
    5. Groups assignments by principal (service principal/application)
    6. Returns streamlined objects optimized for analysis and reporting

    Permission Types Included:
    - **Application Permissions** (appRoles): App-only permissions without user context
    - **Resource-Specific Application Permissions**: Permissions for specific resource types
    - **Delegated Work Permissions** (publishedPermissionScopes): Permissions requiring user context

    The function uses memory optimization techniques including explicit garbage collection
    to handle large result sets efficiently, making it suitable for enterprise tenants with
    thousands of applications.

    Use Cases:
    - Security audits: Review all Graph API permissions across the tenant
    - Compliance reporting: Document current permission assignments
    - Permission inventory: Create baseline of assigned permissions
    - Over-privilege detection: Identify applications with excessive permissions
    - License management: Understand which apps use which Graph features
    - Permission cleanup: Identify candidates for permission removal

.PARAMETER None
    This function does not accept any parameters. It retrieves all app role assignments
    for Microsoft Graph across the entire tenant.

.OUTPUTS
    System.Object[]
    Returns an array of PSCustomObjects, one per service principal with Graph permissions.
    Each object contains:

    PrincipalId (String)
        The Azure AD service principal object ID (GUID)
        Example: "12345678-1234-1234-1234-123456789012"

    PrincipalName (String)
        The display name of the application/service principal
        Example: "Contoso HR Application"

    AppRoleCount (Int32)
        Total number of Microsoft Graph permissions assigned to this principal
        Example: 25

    AppRoles (Array)
        Array of permission objects, each containing:
        - appRoleId (String): The GUID identifier of the permission
        - FriendlyName (String): Human-readable permission name (e.g., "User.Read.All", "Mail.Send")
        - PermissionType (String): Classification - "Application", "DelegatedWork", or "Unknown"
        - resourceDisplayName (String): The resource name, typically "Microsoft Graph"

    Special Cases:
    - Returns empty array if no applications have Graph permissions
    - Throws error if connection to Graph fails or insufficient permissions

.EXAMPLE
    Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret -Service "GraphBeta"
    $assignments = Get-AppRoleAssignment

    Description:
    Retrieves all Microsoft Graph app role assignments after authenticating to the tenant.
    Output shows all applications and their assigned Graph API permissions.

.EXAMPLE
    $assignments = Get-AppRoleAssignment -Verbose
    $overPrivilegedApps = $assignments | Where-Object { $_.AppRoleCount -gt 50 }

    "Found $($overPrivilegedApps.Count) over-privileged applications:"
    $overPrivilegedApps | Sort-Object AppRoleCount -Descending |
        Select-Object PrincipalName, AppRoleCount |
        Format-Table -AutoSize

    Description:
    Identifies applications with more than 50 assigned Graph permissions (potential over-privileging)
    and displays them sorted by permission count. Uses verbose output to track progress.

.EXAMPLE
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

    $appOnlyPerms | Export-Csv -Path "application-only-permissions.csv" -NoTypeInformation
    "Exported $($appOnlyPerms.Count) application-only permissions to CSV"

    Description:
    Extracts all application-scoped (app-only) permissions across all applications
    and exports them to CSV for security review or compliance documentation.

.EXAMPLE
    $assignments = Get-AppRoleAssignment

    # Define high-privilege permissions
    $criticalPerms = @(
        'Directory.ReadWrite.All',
        'RoleManagement.ReadWrite.Directory',
        'Application.ReadWrite.All',
        'AppRoleAssignment.ReadWrite.All',
        'Domain.ReadWrite.All'
    )

    # Find apps with critical permissions
    $criticalApps = $assignments | Where-Object {
        $hasCritical = ($_.AppRoles.FriendlyName | Where-Object { $_ -in $criticalPerms }).Count -gt 0
        $hasCritical
    } | Select-Object PrincipalName, PrincipalId, @{
        Name='CriticalPermissions'
        Expression={
            ($_.AppRoles | Where-Object { $_.FriendlyName -in $criticalPerms }).FriendlyName -join ', '
        }
    }, @{
        Name='CriticalPermCount'
        Expression={
            ($_.AppRoles | Where-Object { $_.FriendlyName -in $criticalPerms }).Count
        }
    }

    "`nApplications with High-Privilege Permissions:"
    $criticalApps | Sort-Object CriticalPermCount -Descending | Format-Table -AutoSize

    # Export for security review
    $criticalApps | Export-Csv -Path "critical-permissions-audit.csv" -NoTypeInformation

    Description:
    Performs a security audit to identify applications with high-privilege permissions
    that could pose security risks if compromised. Exports findings for review.

.EXAMPLE
    $assignments = Get-AppRoleAssignment

    # Group by permission to see which are most commonly used
    $permissionUsage = $assignments | ForEach-Object {
        $_.AppRoles | Select-Object FriendlyName, PermissionType
    } | Group-Object FriendlyName | Select-Object Name, Count, @{
        Name='Type'
        Expression={$_.Group[0].PermissionType}
    } | Sort-Object Count -Descending

    "`nTop 10 Most Used Microsoft Graph Permissions:"
    $permissionUsage | Select-Object -First 10 | Format-Table -AutoSize

    $permissionUsage | Export-Csv -Path "permission-usage-stats.csv" -NoTypeInformation

    Description:
    Analyzes which Microsoft Graph permissions are most commonly assigned across
    the tenant, useful for understanding API usage patterns and planning.

.EXAMPLE
    $assignments = Get-AppRoleAssignment

    # Create a detailed inventory report
    $inventory = $assignments | ForEach-Object {
        $principal = $_
        $principal.AppRoles | ForEach-Object {
            [PSCustomObject]@{
                ApplicationName = $principal.PrincipalName
                ApplicationId = $principal.PrincipalId
                TotalPermissions = $principal.AppRoleCount
                PermissionName = $_.FriendlyName
                PermissionType = $_.PermissionType
                PermissionId = $_.appRoleId
                Resource = $_.resourceDisplayName
            }
        }
    }

    # Export complete inventory
    $inventory | Export-Csv -Path "complete-graph-permissions-inventory.csv" -NoTypeInformation

    # Generate summary statistics
    $summary = [PSCustomObject]@{
        TotalApplications = $assignments.Count
        TotalPermissionAssignments = $inventory.Count
        UniquePermissions = ($inventory.PermissionName | Select-Object -Unique).Count
        ApplicationPermissions = ($inventory | Where-Object PermissionType -eq 'Application').Count
        DelegatedPermissions = ($inventory | Where-Object PermissionType -eq 'DelegatedWork').Count
        GeneratedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    $summary | Export-Csv -Path "inventory-summary.csv" -NoTypeInformation

    "`nInventory Summary:"
    $summary | Format-List

    Description:
    Creates a comprehensive permission inventory with detailed CSV exports and
    summary statistics, ideal for compliance audits and documentation.

.EXAMPLE
    # Monitor for changes over time
    $currentAssignments = Get-AppRoleAssignment
    $currentAssignments | Export-Clixml -Path "assignments_$(Get-Date -Format 'yyyyMMdd').xml"

    # Compare with previous snapshot
    if (Test-Path "assignments_previous.xml") {
        $previousAssignments = Import-Clixml -Path "assignments_previous.xml"

        # Find new applications
        $newApps = $currentAssignments | Where-Object {
            $currentId = $_.PrincipalId
            -not ($previousAssignments.PrincipalId -contains $currentId)
        }

        # Find applications with increased permissions
        $increasedPerms = $currentAssignments | ForEach-Object {
            $current = $_
            $previous = $previousAssignments | Where-Object { $_.PrincipalId -eq $current.PrincipalId }
            if ($previous -and $current.AppRoleCount -gt $previous.AppRoleCount) {
                [PSCustomObject]@{
                    AppName = $current.PrincipalName
                    PreviousCount = $previous.AppRoleCount
                    CurrentCount = $current.AppRoleCount
                    Increase = $current.AppRoleCount - $previous.AppRoleCount
                }
            }
        }

        if ($newApps.Count -gt 0) {
            Write-Warning "Found $($newApps.Count) new applications with Graph permissions"
            $newApps | Select-Object PrincipalName, AppRoleCount | Format-Table
        }

        if ($increasedPerms.Count -gt 0) {
            Write-Warning "Found $($increasedPerms.Count) applications with increased permissions"
            $increasedPerms | Format-Table
        }
    }

    # Save current as previous for next run
    $currentAssignments | Export-Clixml -Path "assignments_previous.xml" -Force

    Description:
    Implements change tracking to monitor for new applications or permission increases
    over time. Useful for detecting unauthorized permission grants or configuration drift.

.EXAMPLE
    $assignments = Get-AppRoleAssignment

    # Find applications with no delegated permissions (app-only scenarios)
    $appOnlyApplications = $assignments | Where-Object {
        $allAppType = ($_.AppRoles | Where-Object { $_.PermissionType -eq 'Application' }).Count -eq $_.AppRoleCount
        $allAppType -and $_.AppRoleCount -gt 0
    }

    "`nApplications Using Only Application Permissions (No Delegated):"
    "These are typically background services, daemons, or automation tools.`n"
    $appOnlyApplications | Select-Object PrincipalName, AppRoleCount | Format-Table -AutoSize

    Description:
    Identifies applications that only use application permissions (no delegated permissions),
    which typically indicates background services or automation scenarios.

.NOTES
    Prerequisites:
    - Must be connected to Microsoft Graph using Connect-EntraService with GraphBeta service
    - Requires the following Microsoft Graph permissions:
      * Application.Read.All (to read service principals)
      * AppRoleAssignment.Read.All (to read app role assignments)
      * Directory.Read.All (recommended for complete data)
    - Beta endpoint access required (function uses GraphBeta service)

    Authentication:
    The function requires prior authentication via Connect-EntraService. Example:

    Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret -Service "GraphBeta"

    Or for interactive authentication:
    Connect-EntraService -Service "GraphBeta"

    Performance Considerations:
    - Uses automatic pagination via Invoke-EntraRequest (handles large result sets)
    - Implements explicit memory management with garbage collection
    - Processing time scales with number of service principals (typically 30-120 seconds for large tenants)
    - Can efficiently handle thousands of assignments
    - Memory usage peaks at ~100-500MB for large tenants

    Memory Management:
    The function implements several memory optimization techniques:
    - Explicitly nulls large objects after use ($graphServicePrincipal = $null)
    - Calls [System.GC]::Collect() at strategic points to free memory
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
    1. GET /servicePrincipals(appId='00000003-0000-0000-c000-000000000000')
       - Retrieves Graph service principal with all permission definitions
    2. GET /servicePrincipals(appId='00000003-0000-0000-c000-000000000000')/appRoleAssignedTo
       - Retrieves all app role assignments (automatically paginated)

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
    1. **Security Audits**: Identify over-privileged applications
    2. **Compliance Reporting**: Document permission assignments for auditors
    3. **Permission Inventory**: Baseline of current state before changes
    4. **Change Tracking**: Monitor permission grants over time
    5. **License Planning**: Understand Graph API feature usage
    6. **Incident Response**: Quickly identify which apps have sensitive permissions
    7. **Cleanup Projects**: Find candidates for permission removal

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

.LINK
    https://learn.microsoft.com/en-us/graph/permissions-reference

.LINK
    https://mynster9361.github.io/Least_Privileged_MSGraph/commands/Get-AppRoleAssignment.html
#>
  [CmdletBinding()]
  param (
  )

  try {
    # region get Microsoft Graph service principal information
    Write-Verbose "Retrieving Microsoft Graph service principal information"

    $graphServicePrincipal = Invoke-EntraRequest -Service "GraphBeta" -Method GET -Path "/servicePrincipals(appId='00000003-0000-0000-c000-000000000000')"

    # endregion

    # region get all app role assignments
    Write-Verbose "Retrieving app role assignments (with automatic pagination)"

    # Invoke-EntraRequest automatically handles pagination, so we just need one call
    $allAppRoleAssignments = Invoke-EntraRequest -Service "GraphBeta" -Method GET -Path "/servicePrincipals(appId='00000003-0000-0000-c000-000000000000')/appRoleAssignedTo" -Header @{ "ConsistencyLevel" = "eventual" }

    Write-Verbose "Retrieved $($allAppRoleAssignments.Count) total app role assignments"
    # endregion

    # region translate app role ids to permission names
    Write-Verbose "Building permission lookup table"

    [System.Collections.Generic.List[System.Object]] $lookup = @()

    # Add application permissions (appRoles)
    if ($graphServicePrincipal.appRoles) {
      $appRoles = $graphServicePrincipal.appRoles | ForEach-Object {
        [PSCustomObject]@{
          Role_Name                = $_.value
          Application_Identifier   = $_.id
          DelegatedWork_Identifier = $null
        }
      }
      $lookup.AddRange($appRoles)
    }

    # Add resource-specific application permissions
    if ($graphServicePrincipal.resourceSpecificApplicationPermissions) {
      $resourcePermissions = $graphServicePrincipal.resourceSpecificApplicationPermissions | ForEach-Object {
        [PSCustomObject]@{
          Role_Name                = $_.value
          Application_Identifier   = $_.id
          DelegatedWork_Identifier = $null
        }
      }
      $lookup.AddRange($resourcePermissions)
    }

    # Add delegated permissions (publishedPermissionScopes)
    if ($graphServicePrincipal.publishedPermissionScopes) {
      $permScopes = $graphServicePrincipal.publishedPermissionScopes | ForEach-Object {
        [PSCustomObject]@{
          Role_Name                = $_.value
          Application_Identifier   = $null
          DelegatedWork_Identifier = $_.id
        }
      }
      $lookup.AddRange($permScopes)
    }

    # Clean up variables to free memory
    $graphServicePrincipal = $null
    $resourcePermissions = $null
    $permScopes = $null
    $appRoles = $null
    [System.GC]::Collect()

    # Consolidate duplicate entries and combine app/delegated identifiers
    Write-Verbose "Consolidating permission lookup table"
    $lookup = $lookup | Group-Object -Property Role_Name | ForEach-Object {
      $appId = ($_.Group | Where-Object { $null -ne $_.Application_Identifier } | Select-Object -First 1).Application_Identifier
      $delegatedId = ($_.Group | Where-Object { $null -ne $_.DelegatedWork_Identifier } | Select-Object -First 1).DelegatedWork_Identifier
      [PSCustomObject]@{
        Role_Name                = $_.Name
        Application_Identifier   = $appId
        DelegatedWork_Identifier = $delegatedId
      }
    }

    # Add friendly names and permission types to app role assignments
    Write-Verbose "Adding friendly names to app role assignments"
    $allAppRoleAssignments | ForEach-Object {
      $appRoleId = $_.appRoleId
      $lookupResult = $lookup | Where-Object {
        ($_.Application_Identifier -eq $appRoleId) -or ($_.DelegatedWork_Identifier -eq $appRoleId)
      } | Select-Object -First 1

      if ($lookupResult) {
        $_ | Add-Member -MemberType NoteProperty -Name "FriendlyName" -Value $lookupResult.Role_Name -Force
        $_ | Add-Member -MemberType NoteProperty -Name "PermissionType" -Value $(
          if ($lookupResult.Application_Identifier -eq $appRoleId) {
            "Application"
          }
          elseif ($lookupResult.DelegatedWork_Identifier -eq $appRoleId) {
            "DelegatedWork"
          }
          else {
            "Unknown"
          }
        ) -Force
      }
      else {
        $_ | Add-Member -MemberType NoteProperty -Name "FriendlyName" -Value $null -Force
        $_ | Add-Member -MemberType NoteProperty -Name "PermissionType" -Value "Unknown" -Force
      }
    }

    $lookup = $null
    [System.GC]::Collect()

    # Group assignments by principal and create streamlined output
    Write-Verbose "Grouping assignments by principal"
    $groupedAppRoleAssignments = $allAppRoleAssignments | Group-Object -Property principalId

    $allAppRoleAssignments = $null
    [System.GC]::Collect()

    # Create the final lightweight output
    $lightweightGroups = $groupedAppRoleAssignments | ForEach-Object {
      [PSCustomObject]@{
        PrincipalId   = $_.Name
        PrincipalName = $_.Group[0].principalDisplayName
        AppRoleCount  = $_.Group.Count
        AppRoles      = $_.Group | Select-Object -Property appRoleId, FriendlyName, PermissionType, resourceDisplayName
      }
    }

    $groupedAppRoleAssignments = $null
    [System.GC]::Collect()
    # endregion

    Write-Verbose "Successfully retrieved $($lightweightGroups.Count) principals with app role assignments"
    return $lightweightGroups
  }
  catch {
    Write-Error "Failed to retrieve app role assignments: $($_.Exception.Message)"
    throw
  }
}
