<#
.SYNOPSIS
    Generates a KQL query to analyze and anonymize Microsoft Graph API calls from Log Analytics.
.DESCRIPTION
    This script generates a KQL query that groups Microsoft Graph API calls by AppId and
    anonymizes the RequestUri by replacing identifiers with placeholders like {id} or {userPrincipalName}.
    It uses common pattern matching to transform URIs into their anonymized form.
.PARAMETER JsonFilePath
    Path to the graph_api_permissions_map.json file. The file is examined but currently not used directly
    for pattern matching. Future versions may integrate more directly with the JSON content.
.PARAMETER OutputFilePath
    Optional path where the generated KQL query will be saved. If not specified, the query is returned as output.
.EXAMPLE
    .\Initialize-GraphKQLQuery.ps1 -JsonFilePath "graph_api_permissions_map.json"
.EXAMPLE
    .\Initialize-GraphKQLQuery.ps1 -JsonFilePath "graph_api_permissions_map.json" -OutputFilePath "graph_query.kql"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$JsonFilePath,

    [Parameter(Mandatory = $false)]
    [string]$OutputFilePath
)

function Get-GraphPatterns {
    # Define common patterns for Microsoft Graph API paths
    # This is an extensible list of patterns to match and anonymize URLs
    $patterns = @(
        # URL query parameters (should be processed first)
        @{
            Pattern = '\?.*$'
            Replacement = ''
            Description = 'URL query parameters'
        },

        # Complex nested patterns - must come before simpler patterns
        @{
            Pattern = 'sites/([^/]+)/sites/([^/]+)/lists/([^/]+)/drive/items/([^/]+)/thumbnails/(\d+)/([^/]+)/([^/]+)'
            Replacement = 'sites/{siteId}/sites/{nestedSiteId}/lists/{listId}/drive/items/{itemId}/thumbnails/{thumbnailIndex}/{size}/{contentOrValue}'
            Description = 'Nested site list drive item thumbnail'
        },
        @{
            Pattern = 'sites/([^/]+)/sites/([^/]+)'
            Replacement = 'sites/{siteId}/sites/{nestedSiteId}'
            Description = 'Nested site within site'
        },
        @{
            Pattern = 'sites/([^/]+)/lists/([^/]+)/drive/items/([^/]+)'
            Replacement = 'sites/{siteId}/lists/{listId}/drive/items/{itemId}'
            Description = 'Site list drive item'
        },
        @{
            Pattern = 'drive/items/([^/]+)/thumbnails/(\d+)/([^/]+)/([^/]+)'
            Replacement = 'drive/items/{itemId}/thumbnails/{thumbnailIndex}/{size}/{contentOrValue}'
            Description = 'Drive item thumbnail'
        },
        @{
            Pattern = 'drive/root:/([^/]+)/thumbnails/(\d+)/([^/]+)/([^/]+)'
            Replacement = 'drive/root:/{item-path}:/thumbnails/{thumbnailIndex}/{size}/{contentOrValue}'
            Description = 'Drive item thumbnail'
        },
        @{
            Pattern = 'users/([^/]+)/mailFolders/([^/]+)/messages'
            Replacement = 'users/{id | userPrincipalName}/mailFolders/{id}/messages'
            Description = 'User mail folder messages'
        },
        @{
            Pattern = 'me/mailFolders/([^/]+)/messages'
            Replacement = 'me/mailFolders/{id}/messages'
            Description = 'Me mail folder messages'
        },
        @{
            Pattern = 'me/calendars/([^/]+)'
            Replacement = 'me/calendars/{id}'
            Description = 'Me calendar'
        },
        @{
            Pattern = 'me/calendars/([^/]+)/(\d+)'
            Replacement = 'me/calendars/{id}/{action}'
            Description = 'Me calendar with action'
        },
        @{
            Pattern = 'me/messages/([^/]+)'
            Replacement = 'me/mailFolders/{id}'
            Description = 'Me mail folder messages'
        },
        @{
            Pattern = 'me/mailFolders/([^/]+)/messages'
            Replacement = 'me/mailFolders/{id}/messages'
            Description = 'Me mail folder messages'
        },


        # Users patterns
        @{
            Pattern = 'users/([^/]+)'
            Replacement = 'users/{id | userPrincipalName}'
            Description = 'User identifier'
        },
        @{
            Pattern = 'users/([^/]+)/calendars/([^/]+)'
            Replacement = 'users/{id | userPrincipalName}/calendars/{id}'
            Description = 'User calendar identifier'
        },
        @{
            Pattern = 'users/([^/]+)/calendars(([^/]+)/calendarPermissions'
            Replacement = 'users/{id | userPrincipalName}/calendars({id})/calendarPermissions'
            Description = 'User calendar Permissions'
        },
        @{
            Pattern = 'users/([^/]+)/events/([^/]+)'
            Replacement = 'users/{id | userPrincipalName}/events/{id}'
            Description = 'User event identifier'
        },
        @{
            Pattern = 'users/([^/]+)/messages/([^/]+)'
            Replacement = 'users/{id | userPrincipalName}/messages/{id}'
            Description = 'User message identifier'
        },
        @{
            Pattern = 'users/([^/]+)/mailFolders/([^/]+)'
            Replacement = 'users/{id | userPrincipalName}/mailFolders/{id}'
            Description = 'User mail folder identifier'
        },
        @{
            Pattern = 'users/([^/]+)/mailFolders(([^/]+)'
            Replacement = 'users/{id | userPrincipalName}/mailFolders({id})'
            Description = 'User mail folder identifier'
        },
        @{
            Pattern = 'users/([^/]+)/contacts/([^/]+)'
            Replacement = 'users/{id | userPrincipalName}/contacts/{id}'
            Description = 'User contact identifier'
        },
        @{
            Pattern = 'users/([^/]+)/drive'
            Replacement = 'users/{id | userPrincipalName}/drive'
            Description = 'User OneDrive'
        },
        @{
            Pattern = 'users/([^/]+)/drive/items/([^/]+)'
            Replacement = 'users/{id | userPrincipalName}/drive/items/{id}'
            Description = 'User OneDrive item'
        },

        # Groups patterns
        @{
            Pattern = 'groups/([^/]+)'
            Replacement = 'groups/{id}'
            Description = 'Group identifier'
        },
        @{
            Pattern = 'groups/([^/]+)/members'
            Replacement = 'groups/{id}/members'
            Description = 'Group members'
        },
        @{
            Pattern = 'groups/([^/]+)/owners'
            Replacement = 'groups/{id}/owners'
            Description = 'Group owners'
        },
        @{
            Pattern = 'groups/([^/]+)/events/([^/]+)'
            Replacement = 'groups/{id}/events/{id}'
            Description = 'Group event'
        },

        # Sites patterns
        @{
            Pattern = 'sites/([^/]+)'
            Replacement = 'sites/{id}'
            Description = 'Site identifier'
        },
        @{
            Pattern = 'sites/([^/]+)/lists/([^/]+)'
            Replacement = 'sites/{id}/lists/{id}'
            Description = 'Site list identifier'
        },
        @{
            Pattern = 'sites/([^/]+)/drive/items/([^/]+)'
            Replacement = 'sites/{id}/drive/items/{itemId}'
            Description = 'Site OneDrive item'
        },

        # Applications patterns
        @{
            Pattern = 'applications/([^/]+)'
            Replacement = 'applications/{id}'
            Description = 'Application identifier'
        },

        # ServicePrincipals patterns
        @{
            Pattern = 'servicePrincipals/([^/]+)'
            Replacement = 'servicePrincipals/{id}'
            Description = 'Service principal identifier'
        },
        @{
            Pattern = 'appRoleAssignedTo/([^/]+)'
            Replacement = 'appRoleAssignedTo/{appRoleAssignment-id}'
            Description = 'Service principal appRoleAssignment-id identifier'
        },
        @{
            Pattern = 'oauth2PermissionGrants/([^/]+)'
            Replacement = 'oauth2PermissionGrants/{id}'
            Description = 'Service principal oauth2PermissionGrants identifier'
        },

        # Devices patterns
        @{
            Pattern = 'devices/([^/]+)'
            Replacement = 'devices/{id}'
            Description = 'Device identifier'
        },

        # DirectoryRoles patterns
        @{
            Pattern = 'directoryRoles/([^/]+)'
            Replacement = 'directoryRoles/{id}'
            Description = 'Directory role identifier'
        },

        # Teams patterns
        @{
            Pattern = 'teams/([^/]+)'
            Replacement = 'teams/{id}'
            Description = 'Team identifier'
        },
        @{
            Pattern = 'teams/([^/]+)/channels/([^/]+)'
            Replacement = 'teams/{id}/channels/{id}'
            Description = 'Team channel identifier'
        },

        # Drive patterns
        @{
            Pattern = 'drives/([^/]+)'
            Replacement = 'drives/{id}'
            Description = 'Drive identifier'
        },
        @{
            Pattern = 'drives/([^/]+)/items/([^/]+)'
            Replacement = 'drives/{id}/items/{id}'
            Description = 'Drive item identifier'
        },

        # Shares patterns
        @{
            Pattern = 'shares/([^/]+)'
            Replacement = 'shares/{shareIdOrEncodedSharingUrl}'
            Description = 'shares identifier'
        },

        # Planner patterns
        @{
            Pattern = 'planner/plans/([^/]+)'
            Replacement = 'planner/plans/{id}'
            Description = 'Planner plan identifier'
        },
        @{
            Pattern = 'planner/tasks/([^/]+)'
            Replacement = 'planner/tasks/{id}'
            Description = 'Planner task identifier'
        },

        # Education patterns
        @{
            Pattern = 'education/classes/([^/]+)'
            Replacement = 'education/classes/{id}'
            Description = 'Education class identifier'
        },
        @{
            Pattern = 'education/users/([^/]+)'
            Replacement = 'education/users/{id}'
            Description = 'Education user identifier'
        },

        # Identity patterns
        @{
            Pattern = 'identityGovernance/([^/]+)/([^/]+)'
            Replacement = 'identityGovernance/{type}/{id}'
            Description = 'Identity governance resource'
        },

        # Chats/messages patterns
        @{
            Pattern = 'chats/([^/]+)'
            Replacement = 'chats/{id}'
            Description = 'Chat identifier'
        },
        @{
            Pattern = 'chats/([^/]+)/messages/([^/]+)'
            Replacement = 'chats/{id}/messages/{id}'
            Description = 'Chat message identifier'
        },

        # Email address patterns
        @{
            Pattern = '([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})'
            Replacement = '{email}'
            Description = 'Email address'
        },

        # GUID pattern (fallback for any unmatched GUIDs)
        @{
            Pattern = '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})'
            Replacement = '{id}'
            Description = 'Generic GUID identifier'
        }
    )

    return $patterns
}

function Generate-KQLQuery {
    param (
        [array]$Patterns
    )

    # Create the base of the KQL query
    $kqlQuery = @"
// Microsoft Graph API Activity Analysis with URI Anonymization
// Groups API calls by AppId and includes all endpoints for each AppId
let GraphData = materialize(MicrosoftGraphActivityLogs
| extend ParsedUri = RequestUri
"@

    # Add the pattern replacements to anonymize the URIs
    foreach ($pattern in $Patterns) {
        $kqlQuery += @"

| extend ParsedUri = replace_regex(ParsedUri, @"$($pattern.Pattern)", "$($pattern.Replacement)")
"@
    }

    # Continue the query with endpoint-level details and then group by AppId
    $kqlQuery += @"
| summarize
    count_requests = count(),
    avg_duration = avg(DurationMs),
    success_count = countif(ResponseStatusCode >= 200 and ResponseStatusCode < 300),
    client_error_count = countif(ResponseStatusCode >= 400 and ResponseStatusCode < 500),
    server_error_count = countif(ResponseStatusCode >= 500)
    by AppId, ApiEndpoint = ParsedUri, RequestMethod, ApiVersion
| extend SuccessRate = 1.0 * success_count / count_requests
);

// Get a list of unique AppIds
GraphData
| summarize by AppId
| extend AppDetails = AppId
| join kind=inner (
    // For each AppId, collect all endpoint details as arrays
    GraphData
    | summarize
        TotalRequests = sum(count_requests),
        EndpointCount = dcount(ApiEndpoint),
        Endpoints = make_list(pack(
            'ApiEndpoint', ApiEndpoint,
            'RequestMethod', RequestMethod,
            'ApiVersion', ApiVersion,
            'RequestCount', count_requests,
            'SuccessCount', success_count,
            'ClientErrorCount', client_error_count,
            'ServerErrorCount', server_error_count,
            'SuccessRate', SuccessRate
        ))
    by AppId
) on AppId
| project
    AppId,
    TotalRequests,
    EndpointCount,
    Endpoints
| order by TotalRequests desc
"@

    return $kqlQuery
}

# Main script execution
try {
    Write-Host "Reading graph permissions map from $JsonFilePath..."

    # Check if file exists
    if (-not (Test-Path $JsonFilePath)) {
        throw "The specified JSON file does not exist: $JsonFilePath"
    }

    # Read the JSON file (for future use - currently we're just using predefined patterns)
    $jsonContent = Get-Content -Path $JsonFilePath -Raw | ConvertFrom-Json

    # Get the graph patterns for URL anonymization
    $patterns = Get-GraphPatterns

    # Generate the KQL query
    $kqlQuery = Generate-KQLQuery -Patterns $patterns

    # Output the query
    if ($OutputFilePath) {
        $kqlQuery | Out-File -FilePath $OutputFilePath -Encoding UTF8
        Write-Host "KQL query saved to $OutputFilePath"
    } else {
        # Return the query as output
        return $kqlQuery
    }
} catch {
    Write-Error "Error generating KQL query: $_"
}
