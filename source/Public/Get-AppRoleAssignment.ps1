function Get-AppRoleAssignment {
  <#
.SYNOPSIS
    Retrieves Microsoft Graph app role assignments for all applications.

.DESCRIPTION
    This function queries Microsoft Graph to get all app role assignments for Microsoft Graph API permissions.
    It retrieves the assignments, translates permission IDs to friendly names, and groups them by principal
    (service principal/application).

    The function performs the following operations:
    1. Retrieves the Microsoft Graph service principal information
    2. Fetches all app role assignments with automatic pagination
    3. Builds a lookup table mapping permission IDs to friendly names
    4. Enriches assignments with permission names and types (Application/Delegated)
    5. Groups assignments by principal for easy analysis
    6. Returns streamlined objects with essential information

    Permission types included:
    - Application permissions (appRoles)
    - Resource-specific application permissions
    - Delegated work permissions (publishedPermissionScopes)

    The function uses memory optimization techniques including explicit garbage collection
    to handle large result sets efficiently.

.PARAMETER None
    This function does not accept any parameters.

.OUTPUTS
    Array
    Returns an array of PSCustomObjects with the following properties:
    - PrincipalId: The service principal ID (object ID) of the application
    - PrincipalName: The display name of the application/service principal
    - AppRoleCount: Total number of app roles (permissions) assigned to this principal
    - AppRoles: Array of role objects, each containing:
      - appRoleId: The GUID of the permission
      - FriendlyName: The permission name (e.g., "User.Read.All", "Mail.Send")
      - PermissionType: Either "Application", "DelegatedWork", or "Unknown"
      - resourceDisplayName: The resource the permission applies to (typically "Microsoft Graph")

.EXAMPLE
    Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret -Service "GraphBeta"
    $assignments = Get-AppRoleAssignment

    Retrieves all app role assignments for Microsoft Graph after authenticating.
    Output shows all applications and their assigned permissions.

.EXAMPLE
    $assignments = Get-AppRoleAssignment -Verbose
    $overPrivilegedApps = $assignments | Where-Object { $_.AppRoleCount -gt 50 }
    $overPrivilegedApps | Format-Table PrincipalName, AppRoleCount

    Finds applications with more than 50 assigned permissions and displays them,
    using verbose output to track progress.

.EXAMPLE
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

    Extracts all application-scoped permissions across all apps and exports to CSV.

.EXAMPLE
    $assignments = Get-AppRoleAssignment
    $criticalPerms = @('Directory.ReadWrite.All', 'RoleManagement.ReadWrite.Directory', 'Application.ReadWrite.All')
    $assignments | Where-Object {
        ($_.AppRoles.FriendlyName | Where-Object { $_ -in $criticalPerms }).Count -gt 0
    } | Select-Object PrincipalName, @{N='CriticalPerms';E={
        ($_.AppRoles | Where-Object { $_.FriendlyName -in $criticalPerms }).FriendlyName -join ', '
    }}

    Identifies applications with high-privilege permissions and shows which ones they have.

.NOTES
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
