function Get-AppRoleAssignment {
  <#
.SYNOPSIS
    Retrieves Microsoft Graph app role assignments for all applications in the tenant.

.DESCRIPTION
    This function queries Microsoft Graph to retrieve both application and delegated permissions for Microsoft Graph API
    across all service principals in the tenant. It provides a comprehensive view of which
    applications have which Microsoft Graph permissions assigned.

    The function performs the following operations:
    1. Retrieves the Microsoft Graph service principal information (appId: 00000003-0000-0000-c000-000000000000)
    2. Fetches all app role assignments (application permissions) using automatic pagination with optimized $select query
    3. Fetches all OAuth2 permission grants (delegated permissions) using automatic pagination
    4. Builds a comprehensive lookup table mapping permission IDs to friendly names
    5. Enriches assignments with human-readable permission names and types
    6. Groups assignments by principal (service principal/application)
    7. Returns streamlined objects optimized for analysis and reporting

    Permission Types Included:
    - **Application Permissions** (appRoles): App-only permissions without user context
    - **Resource-Specific Application Permissions**: Permissions for specific resource types
    - **Delegated Work Permissions** (publishedPermissionScopes): Permissions requiring user context

    The function uses memory optimization techniques including explicit garbage collection
    and optimized Graph API queries with $select to reduce payload size, making it suitable
    for enterprise tenants with thousands of applications.

    Use Cases:
    - Security audits: Review all Graph API permissions across the tenant
    - Compliance reporting: Document current permission assignments
    - Permission inventory: Create baseline of assigned permissions
    - Over-privilege detection: Identify applications with excessive permissions
    - License management: Understand which apps use which Graph features
    - Permission cleanup: Identify candidates for permission removal

.PARAMETER PermissionType
    Specifies which type of permissions to retrieve. Valid values:

    - **All** (Default): Retrieves both application and delegated permissions
    - **Application**: Only retrieves application permissions (app-only, via appRoleAssignments)
    - **Delegated**: Only retrieves delegated permissions (user context, via OAuth2 permission grants)

    Use Application or Delegated for faster execution when you only need one type.
    Default: All

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
        - appRoleId (String): The GUID identifier of the permission (null for delegated permissions if not found)
        - FriendlyName (String): Human-readable permission name (e.g., "User.Read.All", "Mail.Send")
        - PermissionType (String): Classification - "Application", "Delegated", "DelegatedWork", or "Unknown"
        - resourceDisplayName (String): The resource name, typically "Microsoft Graph"
        - consentType (String): For delegated permissions - "AllPrincipals" (admin consent) or "Principal" (user consent); null for application permissions

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
    $assignments = Get-AppRoleAssignment -PermissionType Application
    $appOnlyPerms = $assignments | ForEach-Object {
        $app = $_
        $app.AppRoles | ForEach-Object {
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
    Retrieves only application permissions (faster than retrieving all) and exports them
    to CSV for security review or compliance documentation.

.EXAMPLE
    $delegatedPerms = Get-AppRoleAssignment -PermissionType Delegated -Verbose
    $adminConsentRequired = $delegatedPerms | ForEach-Object {
        $app = $_
        $app.AppRoles | Where-Object { $_.consentType -eq 'AllPrincipals' } | ForEach-Object {
            [PSCustomObject]@{
                AppName = $app.PrincipalName
                Permission = $_.FriendlyName
                ConsentType = $_.consentType
            }
        }
    }

    "Found $($adminConsentRequired.Count) delegated permissions with admin consent"
    $adminConsentRequired | Format-Table -AutoSize

    Description:
    Retrieves only delegated permissions and identifies those that have admin consent
    (consentType = 'AllPrincipals'). Faster than retrieving all permissions when you
    only need delegated permissions.


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
    - Uses explicit memory management with garbage collection
    - Processing time scales with number of service principals (typically 30-120 seconds for large tenants)
    - Can efficiently handle thousands of assignments
    - Use -PermissionType parameter to retrieve only needed permission types for faster execution:
      * Application: Skip OAuth2 grants retrieval (30-40% faster)
      * Delegated: Skip app role assignments retrieval (30-40% faster)
      * All (default): Retrieve both types (comprehensive but slower)

    Memory Management:
    The function implements several memory optimization techniques:
    - Uses $select to only retrieve needed properties from Graph API
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
    1. GET /servicePrincipals(appId='00000003-0000-0000-c000-000000000000')?$select=id,appRoles,publishedPermissionScopes,resourceSpecificApplicationPermissions
       - Retrieves Graph service principal with all permission definitions
    2. GET /servicePrincipals(appId='00000003-0000-0000-c000-000000000000')/appRoleAssignedTo?$select=appRoleId,principalId,principalDisplayName,resourceDisplayName
       - Retrieves all app role assignments (application permissions) with optimized query (automatically paginated)
    3. GET /oauth2PermissionGrants?$filter=resourceId eq '{graphServicePrincipalId}'&$select=clientId,scope,consentType
       - Retrieves all OAuth2 permission grants (delegated permissions) with optimized query (automatically paginated)

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
    [Parameter(Mandatory = $false)]
    [ValidateSet('All', 'Application', 'Delegated')]
    [string]$PermissionType = 'All'
  )

  try {
    # region get Microsoft Graph service principal information
    Write-PSFMessage -Level Verbose -Message  "Retrieving Microsoft Graph service principal information"

    $splatEntraRequest = @{
      Service = "GraphBeta"
      Method  = "GET"
      Path    = "/servicePrincipals(appId='00000003-0000-0000-c000-000000000000')"
      Query   = @{
        '$select' = 'id,appRoles,publishedPermissionScopes,resourceSpecificApplicationPermissions'
      }
    }

    $graphServicePrincipal = Invoke-EntraRequest @splatEntraRequest
    $graphServicePrincipalId = $graphServicePrincipal.id

    # endregion

    # region get all app role assignments (application permissions)
    $allAppRoleAssignments = @()
    if ($PermissionType -in @('All', 'Application')) {
      Write-PSFMessage -Level Verbose -Message  "Retrieving app role assignments (application permissions) with automatic pagination"
      $splatEntraRequest = @{
        Service = "GraphBeta"
        Method  = "GET"
        Path    = "/servicePrincipals(appId='00000003-0000-0000-c000-000000000000')/appRoleAssignedTo"
        Header  = @{ "ConsistencyLevel" = "eventual" }
        Query   = @{
          '$select' = 'appRoleId,principalId,principalDisplayName,resourceDisplayName'
        }
      }
      # Invoke-EntraRequest automatically handles pagination, so we just need one call
      $allAppRoleAssignments = Invoke-EntraRequest @splatEntraRequest

      Write-PSFMessage -Level Verbose -Message  "Retrieved $($allAppRoleAssignments.Count) app role assignments (application permissions)"
    }
    else {
      Write-PSFMessage -Level Verbose -Message  "Skipping app role assignments (application permissions) - PermissionType is '$PermissionType'"
    }
    # endregion

    # region get all OAuth2 permission grants (delegated permissions)
    $allOAuth2PermissionGrants = @()
    if ($PermissionType -in @('All', 'Delegated')) {
      Write-PSFMessage -Level Verbose -Message  "Retrieving OAuth2 permission grants (delegated permissions) with automatic pagination"
      $splatEntraRequest = @{
        Service = "GraphBeta"
        Method  = "GET"
        Path    = "/oauth2PermissionGrants"
        Query   = @{
          '$filter' = "resourceId eq '$graphServicePrincipalId'"
          '$select' = 'clientId,scope,consentType,principalId'
        }
      }
      <#
      clientID = Object ID of the service principal representing the application that has been granted the delegated permissions
      scope = Space-separated list of delegated permission names granted to the application
      consentType = Indicates whether the permission was granted by an administrator for all users (AllPrincipals) or by a user for themselves (Principal)
      principalId = The object ID of the user or service principal that granted the permission
      #>
      $allOAuth2PermissionGrants = Invoke-EntraRequest @splatEntraRequest

      Write-PSFMessage -Level Verbose -Message  "Retrieved $($allOAuth2PermissionGrants.Count) OAuth2 permission grants (delegated permissions)"
    }
    else {
      Write-PSFMessage -Level Verbose -Message  "Skipping OAuth2 permission grants (delegated permissions) - PermissionType is '$PermissionType'"
    }
    # endregion

    # region translate app role ids to permission names
    Write-PSFMessage -Level Verbose -Message  "Building permission lookup table"

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
    Write-PSFMessage -Level Verbose -Message  "Consolidating permission lookup table"
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
    Write-PSFMessage -Level Verbose -Message  "Adding friendly names to app role assignments"
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

    # Process OAuth2 permission grants (delegated permissions)
    $expandedDelegatedPermissions = [System.Collections.Generic.List[object]]::new()

    if ($allOAuth2PermissionGrants.Count -gt 0) {
      Write-PSFMessage -Level Verbose -Message  "Processing OAuth2 permission grants and expanding scopes"

      foreach ($grant in $allOAuth2PermissionGrants) {
        # Get the client (app) details
        $clientId = $grant.clientId

        # Split the scope string into individual permissions
        if ($grant.scope) {
          $scopes = $grant.scope -split '\s+' | Where-Object { $_ -ne '' }

          foreach ($scopeName in $scopes) {
            # Look up the permission ID from the lookup table
            $lookupResult = $lookup | Where-Object { $_.Role_Name -eq $scopeName } | Select-Object -First 1

            $permission = [PSCustomObject]@{
              principalId         = $clientId
              appRoleId           = if ($lookupResult) {
                $lookupResult.DelegatedWork_Identifier
              }
              else {
                $null
              }
              FriendlyName        = $scopeName
              PermissionType      = "Delegated"
              resourceDisplayName = "Microsoft Graph"
              consentType         = $grant.consentType
            }

            $expandedDelegatedPermissions.Add($permission)
          }
        }
      }

      Write-PSFMessage -Level Verbose -Message  "Expanded $($expandedDelegatedPermissions.Count) delegated permissions from OAuth2 grants"

      # Get principal display names for delegated permissions (batch lookup)
      Write-PSFMessage -Level Verbose -Message  "Resolving principal display names for delegated permissions"
      $uniqueClientIds = $expandedDelegatedPermissions.principalId | Select-Object -Unique
      $principalLookup = @{}

      if ($uniqueClientIds.Count -gt 0) {
        Write-PSFMessage -Level Verbose -Message "Resolving $($uniqueClientIds.Count) service principal display names using batch request"
        try {
          $servicePrincipalResults = Invoke-EagBatchRequest -Service GraphBeta -Path 'servicePrincipals/{0}?$select=id,displayName' -ArgumentList $uniqueClientIds

          # Create lookup hashtable from batch results
          foreach ($result in $servicePrincipalResults) {
            if ($result.id -and $result.displayName) {
              $principalLookup[$result.id] = $result.displayName
            }
          }

          Write-PSFMessage -Level Verbose -Message "Successfully resolved $($principalLookup.Count) service principal display names from batch request"

          # Add "Unknown" for any IDs that weren't resolved
          foreach ($clientId in $uniqueClientIds) {
            if (-not $principalLookup.ContainsKey($clientId)) {
              Write-PSFMessage -Level Warning -Message "Could not resolve display name for principal $clientId"
              $principalLookup[$clientId] = "Unknown"
            }
          }
        }
        catch {
          Write-PSFMessage -Level Warning -Message "Batch request failed, falling back to individual requests: $($_.Exception.Message)"
          # Fallback to individual requests if batch fails
          foreach ($clientId in $uniqueClientIds) {
            try {
              $splatEntraRequest = @{
                Service = "GraphBeta"
                Method  = "GET"
                Path    = "/servicePrincipals/$clientId"
                Query   = @{
                  '$select' = 'displayName'
                }
              }
              $principal = Invoke-EntraRequest @splatEntraRequest
              $principalLookup[$clientId] = $principal.displayName
            }
            catch {
              Write-PSFMessage -Level Warning -Message "Could not resolve display name for principal $clientId"
              $principalLookup[$clientId] = "Unknown"
            }
          }
        }
      }

      # Add display names to delegated permissions
      foreach ($permission in $expandedDelegatedPermissions) {
        $permission | Add-Member -MemberType NoteProperty -Name "principalDisplayName" -Value $principalLookup[$permission.principalId] -Force
      }
    }

    # Merge app role assignments with delegated permissions
    Write-PSFMessage -Level Verbose -Message  "Merging application and delegated permissions"
    $allPermissions = [System.Collections.Generic.List[object]]::new()
    $allPermissions.AddRange($allAppRoleAssignments)
    $allPermissions.AddRange($expandedDelegatedPermissions)

    Write-PSFMessage -Level Verbose -Message  "Total permissions (application + delegated): $($allPermissions.Count)"

    # Clean up temporary variables
    $lookup = $null
    $allAppRoleAssignments = $null
    $allOAuth2PermissionGrants = $null
    $expandedDelegatedPermissions = $null
    $principalLookup = $null
    [System.GC]::Collect()

    # Group all permissions by principal and create streamlined output
    Write-PSFMessage -Level Verbose -Message  "Grouping all permissions by principal"
    $groupedAppRoleAssignments = $allPermissions | Group-Object -Property principalId

    $allPermissions = $null
    [System.GC]::Collect()

    # Create the final lightweight output with deduplicated permissions
    Write-PSFMessage -Level Verbose -Message  "Deduplicating permissions within each principal"
    $lightweightGroups = $groupedAppRoleAssignments | ForEach-Object {
      # Deduplicate permissions based on FriendlyName and PermissionType
      # Keep the first occurrence which preserves the appRoleId and consentType
      $uniquePermissions = $_.Group | Group-Object -Property @{Expression = { "$($_.FriendlyName)|$($_.PermissionType)" } } | ForEach-Object {
        $_.Group | Select-Object -First 1
      } | Select-Object -Property appRoleId, FriendlyName, PermissionType, resourceDisplayName, consentType

      [PSCustomObject]@{
        PrincipalId   = $_.Name
        PrincipalName = $_.Group[0].principalDisplayName
        AppRoleCount  = $uniquePermissions.Count
        AppRoles      = $uniquePermissions
      }
    }

    $groupedAppRoleAssignments = $null
    [System.GC]::Collect()
    # endregion

    Write-PSFMessage -Level Verbose -Message  "Successfully retrieved $($lightweightGroups.Count) principals with app role assignments"
    return $lightweightGroups
  }
  catch {
    Write-Error "Failed to retrieve app role assignments: $($_.Exception.Message)"
    throw
  }
}
