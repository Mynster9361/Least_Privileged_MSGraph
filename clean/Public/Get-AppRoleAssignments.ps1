function Get-AppRoleAssignments {
  <#
    .SYNOPSIS
        Retrieves Microsoft Graph app role assignments for all applications.

    .DESCRIPTION
        This function queries Microsoft Graph to get all app role assignments for Microsoft Graph API permissions.
        It returns a streamlined object containing principal information and their assigned permissions with friendly names.
        Uses Invoke-EntraRequest which handles authentication and automatic pagination.

    .EXAMPLE
        # Requires prior connection using Connect-EntraService
        Connect-EntraService -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecret -Service "GraphBeta"
        $assignments = Get-AppRoleAssignments

    .OUTPUTS
        Returns an array of PSCustomObjects with the following properties:
        - PrincipalId: The ID of the principal (app/service principal)
        - PrincipalName: The display name of the principal
        - AppRoleCount: Number of app roles assigned to the principal
        - AppRoles: Array of assigned roles with appRoleId, FriendlyName, PermissionType, and resourceDisplayName
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
      $appId = ($_.Group | Where-Object { $_.Application_Identifier -ne $null } | Select-Object -First 1).Application_Identifier
      $delegatedId = ($_.Group | Where-Object { $_.DelegatedWork_Identifier -ne $null } | Select-Object -First 1).DelegatedWork_Identifier
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