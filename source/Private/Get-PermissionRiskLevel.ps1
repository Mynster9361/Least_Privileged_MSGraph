function Get-PermissionRiskLevel {
    <#
.SYNOPSIS
    Determines the risk level of a Microsoft Graph permission using multi-factor analysis.

.DESCRIPTION
    Calculates a numeric risk level (1–5) and a descriptive label for a given Graph permission
    by combining four factors in priority order:

    1. **Microsoft Graph permissions schema** – the official `privilegeLevel` value from
       Microsoft's permissions.json, fetched scope-aware (Application vs DelegatedWork).
       When the permission is found in the schema this value is returned directly, since
       the schema already differentiates between Application and Delegated grant types.

    2. **Critical/High override list** – curated patterns for permissions that carry inherent
       tenant-wide security risk, used as fallback when the permission is absent from the
       schema (e.g. RoleManagement.*, Directory.ReadWrite.All, Application.ReadWrite.All).

    3. **Name-pattern analysis** – infers risk from permission name conventions when the
       permission is absent from both the schema and the override lists
       (.ReadWrite.All → High, .Read.All → Medium, etc.).

    4. **Scope type adjustment** – applied only for schema-less fallback paths.  Application
       grants have no user context, persist indefinitely, and have full tenant blast radius.
       The level is bumped by +1 (capped at 5) after name-pattern inference.

    Risk levels:
      1 – Low:      Minimal scope, read-only or per-user (e.g. User.Read, openid, profile)
      2 – Medium:   Moderate access; limited write or scoped tenant-read (e.g. Group.Read.All)
      3 – High:     Broad read or write, significant data exposure (e.g. Mail.Send, AuditLog.Read.All)
      4 – Critical: Can fundamentally compromise tenant security (e.g. RoleManagement.ReadWrite.All)
      5 – Maximum:  Highest risk tier as defined by the Graph permissions schema
                    (e.g. DelegatedPermissionGrant.ReadWrite.All, BackupRestore-*.ReadWrite.All)

.PARAMETER PermissionName
    The Microsoft Graph permission name (e.g. "User.Read.All", "Directory.ReadWrite.All").

.PARAMETER ScopeType
    The permission grant type. Accepted values:
    - "Application"       (app-only, no user context)
    - "Delegated"         (acts on behalf of a signed-in user)
    - "DelegatedWork"     (same as Delegated, work/school account)
    - "DelegatedPersonal" (personal Microsoft account)

.PARAMETER Schema
    Optional. The Microsoft Graph permissions schema as a hashtable, obtained by calling
    Invoke-RestMethod on permissions.json and piping through ConvertFrom-Json -AsHashtable.
    When provided it is used as the baseline level before name-pattern and scope adjustments.

.OUTPUTS
    PSCustomObject
    - Level (int):   Risk level 1–4
    - Label (string): "Low", "Medium", "High", or "Critical"

.EXAMPLE
    $risk = Get-PermissionRiskLevel -PermissionName "Directory.ReadWrite.All" -ScopeType "Application"
    # Level=4, Label="Critical"  (critical override + Application scope)

.EXAMPLE
    $risk = Get-PermissionRiskLevel -PermissionName "User.Read" -ScopeType "Delegated"
    # Level=1, Label="Low"

.EXAMPLE
    $risk = Get-PermissionRiskLevel -PermissionName "User.Read.All" -ScopeType "Application" -Schema $schema
    # Level=4 (schema may say 3, but Application scope bumps it to 4)

.EXAMPLE
    $risk = Get-PermissionRiskLevel -PermissionName "Mail.Send" -ScopeType "Application"
    # Level=3, Label="High"  (high override, no further Application bump because 3+1=4 would apply,
    # but this permission already lands in the High override returning 3 for Application scope)

.NOTES
    - When the Schema parameter is provided and the permission is found, the schema value
      is returned immediately — no additional overrides or scope adjustment are applied,
      since the schema already differentiates by scope.
    - Override patterns are only consulted when the permission is absent from the schema.
    - The Application scope bump (+1, capped at 5) is applied only for schema-less fallback paths.
    - Scope values "DelegatedWork" and "DelegatedPersonal" are both treated as Delegated.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PermissionName,

        [Parameter(Mandatory = $true)]
        [string]$ScopeType,

        [Parameter()]
        [hashtable]$Schema = $null
    )

    $isApplication = $ScopeType -eq 'Application'
    $schemaKey = if ($isApplication) {
        'Application'
    }
    else {
        'DelegatedWork'
    }

    # -------------------------------------------------------------------------
    # 1. Schema-based level (primary source)
    #    Use Microsoft's official privilegeLevel for this permission and scope
    #    directly from permissions.json.  The schema already differentiates
    #    between Application and Delegated scope, so no additional bump is needed
    #    when a schema match is found.  Supports levels 1–5.
    # -------------------------------------------------------------------------
    if ($null -ne $Schema) {
        $permissions = $Schema['permissions']
        if ($permissions -is [hashtable] -and $permissions.ContainsKey($PermissionName)) {
            $permNode = $permissions[$PermissionName]
            if ($permNode -is [hashtable]) {
                $schemes = $permNode['schemes']
                if ($schemes -is [hashtable] -and $schemes.ContainsKey($schemaKey)) {
                    $schemeNode = $schemes[$schemaKey]
                    if ($schemeNode -is [hashtable]) {
                        $rawLevel = $schemeNode['privilegeLevel']
                        if ($null -ne $rawLevel) {
                            $parsed = [int]$rawLevel
                            if ($parsed -gt 0) {
                                $label = switch ($parsed) {
                                    5 {
                                        'Maximum'
                                    }
                                    4 {
                                        'Critical'
                                    }
                                    3 {
                                        'High'
                                    }
                                    2 {
                                        'Medium'
                                    }
                                    default {
                                        'Low'
                                    }
                                }
                                return [PSCustomObject]@{ Level = $parsed; Label = $label }
                            }
                        }
                    }
                }
            }
        }
    }

    # -------------------------------------------------------------------------
    # 2. Critical override patterns (fallback when permission absent from schema)
    #    Permissions that can fundamentally compromise tenant security.
    #    Application scope → Critical (4).  Delegated scope → High (3) because
    #    the user's own permissions act as a ceiling, but the capability is still
    #    dangerous if the account is compromised.
    # -------------------------------------------------------------------------
    $criticalPatterns = @(
        'RoleManagement.*',                           # Assign/modify Entra ID roles
        'PrivilegedAccess.*',                         # PIM operations
        'Directory.ReadWrite.All',                    # Full directory write
        'Policy.ReadWrite.*',                         # Security and tenant policies
        'Application.ReadWrite.All',                  # Create/modify app registrations
        'AppRoleAssignment.ReadWrite.All',            # Grant application permissions
        'DelegatedPermissionGrant.ReadWrite.All',     # Grant OAuth delegated consents
        'UserAuthenticationMethod.ReadWrite.All',     # Modify MFA / passwordless methods
        'Domain.ReadWrite.All',                       # Manage verified domains
        'OnPremDirectorySynchronization.ReadWrite.All', # Control AD Connect sync
        'ServicePrincipalEndpoint.ReadWrite.All',     # Modify service principal endpoints
        'EntitlementManagement.ReadWrite.All',        # Access packages and policies
        'SecurityActions.ReadWrite.All'               # Trigger security response actions
    )

    foreach ($pattern in $criticalPatterns) {
        if ($PermissionName -like $pattern) {
            if ($isApplication) {
                return [PSCustomObject]@{ Level = 4; Label = 'Critical' }
            }
            # Delegated: user-bounded but still High
            return [PSCustomObject]@{ Level = 3; Label = 'High' }
        }
    }

    # -------------------------------------------------------------------------
    # 3. High override patterns (fallback when permission absent from schema)
    #    Significant data exposure or write capability even without full directory
    #    write.  Application scope → High (3).  Delegated scope → Medium (2).
    # -------------------------------------------------------------------------
    $highPatterns = @(
        'Directory.Read.All',                # Read entire directory (incl. sensitive attributes)
        'Directory.ReadWrite.*',             # Any other Directory write (not .All caught above)
        'User.ReadWrite.All',                # Write to all users
        'Group.ReadWrite.All',               # Write to all groups (and members)
        'Mail.ReadWrite.*',                  # Read and write all mailbox content
        'Mail.Send',                         # Send mail as any user in the tenant
        'Mail.Send.Shared',                  # Send from shared mailboxes
        'Calendars.ReadWrite.All',           # Read/write all calendars
        'Files.ReadWrite.All',               # Read/write all files in OneDrive/SharePoint
        'Sites.ReadWrite.All',               # Read/write all SharePoint sites
        'AuditLog.Read.All',                 # Access security audit logs
        'Reports.Read.All',                  # Organizational usage reports
        'SecurityEvents.*',                  # Security incidents and alerts
        'IdentityRiskyUser.*',               # User risk data
        'IdentityRiskEvent.*',               # Sign-in risk event data
        'Application.ReadWrite.OwnedBy',     # Modify owned app registrations
        'User.Export.All',                   # Bulk export user data (GDPR-sensitive)
        'User.ManageIdentities.All',         # Manage external identities for all users
        'BitlockerKey.Read.All',             # Read BitLocker recovery keys
        'InformationProtectionContent.*',    # AIP/MIP protected content
        'TrustFrameworkKeySet.*',            # B2C trust framework keys
        'IdentityProvider.ReadWrite.All',    # Manage identity providers
        'AccessReview.ReadWrite.All'         # Approve/deny access reviews
    )

    foreach ($pattern in $highPatterns) {
        if ($PermissionName -like $pattern) {
            if ($isApplication) {
                return [PSCustomObject]@{ Level = 3; Label = 'High' }
            }
            return [PSCustomObject]@{ Level = 2; Label = 'Medium' }
        }
    }

    # -------------------------------------------------------------------------
    # 4. Name-pattern inference (fallback when permission is absent from schema
    #    and does not match any override list)
    #    Inferred from standard Graph permission naming conventions.
    # -------------------------------------------------------------------------
    $nameLevel = 1
    if ($PermissionName -match '\.(ReadWrite|Write|Manage)\.All$') {
        $nameLevel = 3
    }
    elseif ($PermissionName -match '\.ReadWrite$' -or $PermissionName -match '\.Write$') {
        $nameLevel = 2
    }
    elseif ($PermissionName -match '\.Read\.All$' -or $PermissionName -match '\.ReadBasic\.All$') {
        $nameLevel = 2
    }

    # -------------------------------------------------------------------------
    # 5. Scope type adjustment (applied only for schema-less fallback paths)
    #    Application permissions are persistent and have full tenant blast radius
    #    with no user-context ceiling.  Bump the level by +1 (capped at 5).
    # -------------------------------------------------------------------------
    $baseLevel = $nameLevel

    if ($isApplication -and $baseLevel -lt 5) {
        $baseLevel = [Math]::Min($baseLevel + 1, 5)
    }

    $label = switch ($baseLevel) {
        5 {
            'Maximum'
        }
        4 {
            'Critical'
        }
        3 {
            'High'
        }
        2 {
            'Medium'
        }
        default {
            'Low'
        }
    }

    return [PSCustomObject]@{ Level = $baseLevel; Label = $label }
}
