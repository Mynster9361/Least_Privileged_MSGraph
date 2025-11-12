#region setup required variables
# authentication variables
$tenantId = "replace with your tenant id" # replace with your tenant id
$clientId = "replace with your client id" # replace with your client id
$clientSecret = "replace with your client secret" # replace with your client secret
$authUri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

# log analytics variables
$logAnalyticsAuthUri = "https://login.microsoftonline.com/$tenantId/oauth2/token"
$resource = "api.loganalytics.io"
$authBody = "grant_type=client_credentials&client_id=$($clientId)&client_secret=$($clientSecret)&resource=https://$resource"
$daysToQuery = 30
$logAnalyticsWorkspace = 'replace with your log analytics workspace name' # replace with your log analytics workspace name
$logAnalyticsWorkspaceId = "replace with your log analytics workspace id" # replace with your log analytics workspace id

#endregion setup required variables

#region connect to msgraph with app read all permission
# Enable garbage collection at the beginning
[System.GC]::GetTotalMemory($true) | Out-Null

# Default Token Body
$tokenBody = @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    Client_Id     = $clientId
    Client_Secret = $clientSecret
}

# Request a Token
$tokenResponse = Invoke-RestMethod -Uri $authUri -Method POST -Body $tokenBody

# Setting up the authorization headers
$authHeaders = @{
    "Authorization" = "Bearer $($tokenResponse.access_token)"
    "Content-type"  = "application/json"
}

#endregion connect to msgraph with app read all permission


#region get all apps with msgraph permissions assigned

$body = @{
    requests = @(
        @{
            id     = 1
            method = "GET"
            url    = "/servicePrincipals(appId='00000003-0000-0000-c000-000000000000')"
        },
        @{
            id      = 2
            method  = "GET"
            url     = "/servicePrincipals(appId='00000003-0000-0000-c000-000000000000')/appRoleAssignedTo"
            headers = @{
                "consistencyLevel" = "eventual"
            }
        }
    )
} | ConvertTo-Json -Depth 10

$t = invoke-restmethod -Uri "https://graph.microsoft.com/beta/`$batch" -Method POST -Body $body -Headers $authHeaders
[System.Collections.Generic.List[System.Object]] $allAppRoleAssignments = @()

$allAppRoleAssignments.addrange($($t.responses | Where-Object { $_.id -eq 2 }).body.value)

foreach ($response in $t.responses.body) {
    do {
        # Check if there is a next page
        if ($response.'@odata.nextLink') {
            $uri = $response.'@odata.nextLink'
            # Get the next page
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $authHeaders
            # Add the results to the array
            $allAppRoleAssignments.addrange($response.value)
        
            # Collect garbage after each page to keep memory usage low
            [System.GC]::Collect()
        }
    } while ($response.'@odata.nextLink')
}

#endregion get all apps with msgraph permissions assigned

#region translate app role ids to permission names

# Create lookup from 
<#
#$($t.responses | Where-Object {$_.id -eq 1}).body.appRoles
Sample:
allowedMemberTypes         : {Application}
description                : Allows the app to read access reviews, reviewers, decisions and settings in the organization, without a signed-in user.
displayName                : Read all access reviews
id                         : d07a8cc0-3d51-4b77-b3b0-32704d1f69fa
isEnabled                  : True
origin                     : Application
value                      : AccessReview.Read.All
isPreAuthorizationRequired : False
isPrivate                  : False

#$($t.responses | Where-Object {$_.id -eq 1}).body.resourceSpecificApplicationPermissions
Sample:
description : Allows the app to read user AI enterprise interactions, without a signed-in user.
displayName : Read user AI enterprise interactions.
id          : 10d712aa-b4cd-4472-b0ba-6196e04c344f
value       : AiEnterpriseInteraction.Read.User
isEnabled   : True

#$($t.responses | Where-Object {$_.id -eq 1}).body.publishedPermissionScopes
Sample:
adminConsentDescription : Allows the app to read access reviews, reviewers, decisions and settings that the signed-in user has access to in the organization.
adminConsentDisplayName : Read all access reviews that user can access
id                      : ebfcd32b-babb-40f4-a14b-42706e83bd28
isEnabled               : True
type                    : Admin
userConsentDescription  : Allows the app to read information on access reviews, reviewers, decisions and settings that you have access to.
userConsentDisplayName  : Read access reviews that you can access
value                   : AccessReview.Read.All
isPrivate               : False
#>

# Create the lookup list
[System.Collections.Generic.List[System.Object]] $lookup = @()

$appRoles = $t.responses | Where-Object { $_.id -eq 1 } | Select-Object -ExpandProperty body | 
Select-Object -ExpandProperty appRoles | ForEach-Object {
    [PSCustomObject]@{
        Role_Name                = $_.value
        Application_Identifier   = $_.id
        DelegatedWork_Identifier = $null
    }
}
$lookup.AddRange($appRoles)

$resourcePermissions = $t.responses | Where-Object { $_.id -eq 1 } | Select-Object -ExpandProperty body | 
Select-Object -ExpandProperty resourceSpecificApplicationPermissions | ForEach-Object {
    [PSCustomObject]@{
        Role_Name                = $_.value
        Application_Identifier   = $_.id
        DelegatedWork_Identifier = $null
    }
}
$lookup.AddRange($resourcePermissions)

$permScopes = $t.responses | Where-Object { $_.id -eq 1 } | Select-Object -ExpandProperty body | 
Select-Object -ExpandProperty publishedPermissionScopes | ForEach-Object {
    [PSCustomObject]@{
        Role_Name                = $_.value
        Application_Identifier   = $null
        DelegatedWork_Identifier = $_.id
    }
}
$lookup.AddRange($permScopes)

$t = $null
$resourcePermissions = $null
$permScopes = $null
$appRoles = $null
[System.GC]::Collect()

# Remove any duplicate entries in the lookup and combine the once where there are both app and delegated identifiers
$lookup = $lookup | Group-Object -Property Role_Name | ForEach-Object {
    $appId = ($_.Group | Where-Object { $_.Application_Identifier -ne $null } | Select-Object -First 1).Application_Identifier
    $delegatedId = ($_.Group | Where-Object { $_.DelegatedWork_Identifier -ne $null } | Select-Object -First 1).DelegatedWork_Identifier
    [PSCustomObject]@{
        Role_Name                = $_.Name
        Application_Identifier   = $appId
        DelegatedWork_Identifier = $delegatedId
    }
}

# Match app role IDs with friendly names and track the permission type
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

# Combine allAppRoleAssignments results into groups based on principalId
$groupedAppRoleAssignments = $allAppRoleAssignments | Group-Object -Property principalId

$allAppRoleAssignments = $null
[System.GC]::Collect()

# Create a streamlined version of the grouped assignments
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

#endregion translate app role ids to permission names

#region lookup app activity in log analytics workspace

function Get-AppActivityFromLogs {
    param(
        $logAnalyticsWorkspace,
        $authHeaders,
        $days,
        $spId
    )
    Write-Debug "Querying Log Analytics for app activity in the last $days days..."
    $body = @{
        query            = 'MicrosoftGraphActivityLogs
| where ServicePrincipalId == "' + $spId + '"
| where RequestUri !in("https://graph.microsoft.com/beta/$batch","https://graph.microsoft.com/v1.0/$batch")
| where ResponseStatusCode == "200"
| where isnotempty(AppId) and isnotempty(RequestUri) and isnotempty(RequestMethod)
| extend CleanedRequestUri = iff(indexof(RequestUri, "?") != -1, substring(RequestUri, 0, indexof(RequestUri, "?")), RequestUri)
| extend CleanedRequestUri = replace_string(CleanedRequestUri, "https://", "HTTPSPLACEHOLDER://")
| extend CleanedRequestUri = replace_regex(CleanedRequestUri, "//+", "/")
| extend CleanedRequestUri = replace_string(CleanedRequestUri, "HTTPSPLACEHOLDER:/", "https://")
| project AppId, RequestMethod, CleanedRequestUri
| distinct AppId, RequestMethod, CleanedRequestUri
| summarize Activity = make_set(pack("Method", RequestMethod, "Uri", CleanedRequestUri)) by AppId'
        options          = @{
            truncationMaxSize = 67108864
        }
        maxRows          = 1001
        workspaceFilters = @{
            regions = @()
        }
    } | ConvertTo-Json -Depth 10

    try {
        $t = invoke-restmethod -Uri "https://api.loganalytics.azure.com/v1/workspaces/$logAnalyticsWorkspace/query?timespan=P$($days)D" -Method POST -Headers $authHeaders -Body $body
        $activity = $t.tables.rows[1] | convertfrom-json
        Write-Debug "Found $($activity.Count) api calls for $spId."
        return $activity
    }
    catch {
        Write-Debug"Failed to query Log Analytics workspace. Error: $_"
        return $null
    }

}

$Response = Invoke-RestMethod -Method Post -Uri $logAnalyticsAuthUri -Body $authBody

$logAnalyticsAuthHeaders = @{
    "Authorization" = "Bearer $($Response.access_token)"
    "Content-type"  = "application/json"
}

foreach ($app in $lightweightGroups) {
    $spId = $app.PrincipalId
    try {
       
        $activity = Get-AppActivityFromLogs -logAnalyticsWorkspace $logAnalyticsWorkspaceId -authHeaders $logAnalyticsAuthHeaders -days $daysToQuery -spId $spId
        if ($activity -ne $null) {
            $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value $activity -Force
        }
        else {
            $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
            Write-Debug "No activity found for $($app.PrincipalName)."
        }
    }
    catch {
        Write-Debug "Error retrieving activity for $($app.PrincipalName): $_"
        $app | Add-Member -MemberType NoteProperty -Name "Activity" -Value @() -Force
    }
}

#endregion lookup app activity in log analytics workspace

#region cleanup activity log data by splitting on ? selecting the first value as the uri and then we remove all duplicates
function GraphUri_ConvertRelativeUriToAbsoluteUri {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Uri
    )
    
    Write-Debug "Original URI: $Uri"
    
    $Value = $Uri.TrimStart("/", "\").TrimEnd("/", "\")
    $Value = [System.Uri]::UnescapeDataString($Value)
    $UriBuilder = New-Object System.UriBuilder -ArgumentList $Value

    # Handle /me segment replacement
    $ContainsMeSegment = $False
    $Segments = $UriBuilder.Uri.Segments
    foreach ($s in $Segments) {
        $segmentName = $s.TrimEnd('/')
        if ($segmentName -eq "me") {
            $ContainsMeSegment = $True
            Write-Debug "Found /me segment: $s"
            break
        }
    }
    
    $ProcessedUri = $UriBuilder.Uri.AbsoluteUri
    
    if ($ContainsMeSegment) {
        Write-Debug "Replacing /me/ with /users/{id}/"
        $ProcessedUri = $ProcessedUri.Replace("/me/", "/users/{id}/")
        $ProcessedUri = $ProcessedUri -replace "/me$", "/users/{id}"
        Write-Debug "After /me replacement: $ProcessedUri"
    }
    
    # Handle email segment replacement
    $ContainsAtEmailSegment = $False
    foreach ($s in $Segments) {
        if ($s.Contains("@")) {
            Write-Debug "Found email segment: $s"
            $ContainsAtEmailSegment = $True
            break
        }
    }
    
    if ($ContainsAtEmailSegment) {
        Write-Debug "Replacing email segment in URI: $ProcessedUri"
        $ProcessedUri = $ProcessedUri -replace "/[^/]+@[^/]+", "/{id}"
        Write-Debug "After email replacement: $ProcessedUri"
    }
    
    Write-Debug "Final processed URI: $ProcessedUri"
    
    $returnObject = [PSCustomObject]@{
        Uri     = $ProcessedUri
        Path    = $ProcessedUri -replace "https://graph.microsoft.com/(v1.0|beta)", ""
        Version = if ($ProcessedUri -like "*https://graph.microsoft.com/v1.0*") { "v1.0" } elseif ($ProcessedUri -like "*https://graph.microsoft.com/beta*") { "beta" } else { "" }
    }

    return $returnObject
}

function GraphUri_TokenizeIds {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$UriString
    )
    Write-Debug "Tokenizing URI: $UriString"
    $Uri = [System.Uri]::new($UriString)

    $TokenizedUri = $Uri.GetComponents([System.UriComponents]::SchemeAndServer, [System.UriFormat]::SafeUnescaped)
    write-Debug "Base URI: $TokenizedUri"
    $LastSegmentIndex = $Uri.Segments.length - 1
    write-Debug "Last Segment Index: $LastSegmentIndex"
    $LastSegment = $Uri.Segments[$LastSegmentIndex]
    write-Debug "Last Segment: $LastSegment"
    $UnescapedUri = $Uri.ToString()
    write-Debug "Unescaped URI: $UnescapedUri"
    for ($i = 0 ; $i -lt $Uri.Segments.length; $i++) {
        write-Debug "Processing Segment [$i]: $($Uri.Segments[$i])"
        # Segment contains an integer/id and is not API version.
        if ($Uri.Segments[$i] -match "[^v1.0|beta]\d") {
            write-Debug "Segment [$i] matches ID pattern."
            #For Uris whose last segments match the regex '(.*?)', all characters from the first '(' are substituted with '.*' 
            if ($i -eq $LastSegmentIndex) {
                write-Debug "Segment [$i] is the last segment."
                if ($UnescapedUri -match '(.*?)') {
                    write-Debug "Last segment matches pattern '(.*?)'."
                    try {
                        $UpdatedLastSegment = $LastSegment.Substring(0, $LastSegment.IndexOf("("))
                        $TokenizedUri += $UpdatedLastSegment + "/{id}"
                        write-Debug "Updated Last Segment: $UpdatedLastSegment.*"
                    }
                    catch {
                        $TokenizedUri += "{id}/"
                        write-Debug "Error processing last segment with '(.*?)' pattern. Substituted with {id}/"
                    }
                }
            }
            else {
                write-Debug "Substituting Segment [$i] with {id}/"
                # Substitute integers/ids with {id} tokens, e.g, /users/289ee2a5-9450-4837-aa87-6bd8d8e72891 -> users/{id}.
                $TokenizedUri += "{id}/"
            }
        }
        else {
            write-Debug "Segment [$i] does not match ID pattern. Keeping original segment."
            $TokenizedUri += $Uri.Segments[$i]
        }
    }
    write-Debug "Final Tokenized URI: $TokenizedUri"
    return $TokenizedUri.TrimEnd("/")
}

Foreach ($app in $lightweightGroups) {
    $uniqueActivity = @()
    foreach ($entry in $app.Activity) {
        $processedUriObject = GraphUri_ConvertRelativeUriToAbsoluteUri -Uri $entry.Uri
        $tokenizedUri = GraphUri_TokenizeIds -UriString $processedUriObject.Uri
        $uniqueActivity += [PSCustomObject]@{
            Method = $entry.Method
            Uri    = $tokenizedUri
        }
    }
    # Remove duplicates
    $app | Add-Member -MemberType NoteProperty -Name "UniqueActivity" -Value ($uniqueActivity | Sort-Object -Property Method, Uri -Unique) -Force
}
#endregion cleanup activity log data by splitting on ? selecting the first value as the uri and then we remove all duplicates

#region remove noteproperty Activity to reduce size of the object
$lightweightGroups | ForEach-Object {
    $_.PSObject.Properties.Remove("Activity")
}
[System.GC]::Collect()

#endregion remove noteproperty Activity to reduce size of the object
#region compare app activity and permissions to the permissions map json to see if the app is using the permissions assigned to it

function Find-LeastPrivilegedPermissions {
    param(
        [array]$userActivity,
        [array]$permissionMapv1,
        [array]$permissionMapbeta
    )
    
    Write-Debug "Finding least privileged permissions for activities..."
    
    $results = @()
    
    foreach ($activity in $userActivity) {
        $method = $activity.Method
        $uri = $activity.Uri
        
        # Extract version and path
        $version = if ($uri -like "*https://graph.microsoft.com/v1.0*") { 
            "v1.0" 
        }
        elseif ($uri -like "*https://graph.microsoft.com/beta*") { 
            "beta" 
        }
        else { 
            continue 
        }
        
        $path = ($uri -split "https://graph.microsoft.com/$version")[1]
        if (-not $path) { continue }
        
        # Ensure path starts with /
        if (-not $path.StartsWith('/')) {
            $path = '/' + $path
        }
        
        # Choose correct permission map
        $permissionMap = if ($version -eq "v1.0") { $permissionMapv1 } else { $permissionMapbeta }
        
        # Find matching endpoint
        $matchedEndpoint = $null
        foreach ($endpoint in $permissionMap) {
            # Normalize paths for comparison
            $normalizedEndpoint = $endpoint.Endpoint -replace '\{[^}]+\}', '{id}'
            $normalizedPath = $path -replace '/[0-9a-fA-F-]{36}', '/{id}' -replace '/[^/]+@[^/]+', '/{id}'
            
            if ($normalizedPath -eq $normalizedEndpoint) {
                $matchedEndpoint = $endpoint
                break
            }
        }
        
        $leastPrivilegedPerms = @()
        
        if ($matchedEndpoint) {
            # Get permissions for this specific HTTP method
            if ($matchedEndpoint.Method.PSObject.Properties.Name -contains $method) {
                $methodPermissions = $matchedEndpoint.Method.$method
                
                # Filter to only least privileged permissions
                $leastPrivilegedPerms = $methodPermissions | Where-Object { 
                    $_.isLeastPrivilege -eq $true -and 
                    $_.scopeType -eq "Application" 
                } | Select-Object -Property @{N = 'Permission'; E = { $_.value } }, @{N = 'ScopeType'; E = { $_.scopeType } }, @{N = 'IsLeastPrivilege'; E = { $_.isLeastPrivilege } }
                
                # If no least privileged marked, get all Application scope permissions
                if ($leastPrivilegedPerms.Count -eq 0) {
                    $leastPrivilegedPerms = $methodPermissions | Where-Object { 
                        $_.scopeType -eq "Application" 
                    } | Select-Object -Property @{N = 'Permission'; E = { $_.value } }, @{N = 'ScopeType'; E = { $_.scopeType } }, @{N = 'IsLeastPrivilege'; E = { $_.isLeastPrivilege } }
                }
            }
        }
        
        $results += [PSCustomObject]@{
            Method                     = $method
            Version                    = $version
            Path                       = $path
            OriginalUri                = $uri
            MatchedEndpoint            = if ($matchedEndpoint) { $matchedEndpoint.Endpoint } else { $null }
            LeastPrivilegedPermissions = $leastPrivilegedPerms
            IsMatched                  = $null -ne $matchedEndpoint
        }
    }
    
    return $results
}

function Get-OptimalPermissionSet {
    param(
        [array]$activityPermissions
    )
    
    Write-Debug "Calculating optimal permission set..."
    
    # Check for unmatched activities
    $unmatchedActivities = $activityPermissions | Where-Object { -not $_.IsMatched }
    $matchedActivities = $activityPermissions | Where-Object { $_.IsMatched }
    
    if ($unmatchedActivities.Count -gt 0) {
        Write-Warning "Found $($unmatchedActivities.Count) activities without matches in permission map:"
        $unmatchedActivities | ForEach-Object {
            Write-Warning "  $($_.Method) $($_.Version)$($_.Path)"
        }
    }
    
    if ($matchedActivities.Count -eq 0) {
        return [PSCustomObject]@{
            OptimalPermissions  = @()
            UnmatchedActivities = $unmatchedActivities
            TotalActivities     = $activityPermissions.Count
            MatchedActivities   = 0
        }
    }
    
    # Collect all unique permissions across all activities
    $allPermissions = @{}
    
    foreach ($activity in $matchedActivities) {
        foreach ($perm in $activity.LeastPrivilegedPermissions) {
            $key = "$($perm.Permission)|$($perm.ScopeType)"
            
            if (-not $allPermissions.ContainsKey($key)) {
                $allPermissions[$key] = @{
                    Permission       = $perm.Permission
                    ScopeType        = $perm.ScopeType
                    IsLeastPrivilege = $perm.IsLeastPrivilege
                    Activities       = [System.Collections.Generic.List[object]]::new()
                }
            }
            
            $activityId = "$($activity.Method)|$($activity.Version)|$($activity.Path)"
            if ($allPermissions[$key].Activities -notcontains $activityId) {
                [void]$allPermissions[$key].Activities.Add($activityId)
            }
        }
    }
    
    # Convert to array and sort by coverage (most activities covered first)
    $sortedPermissions = $allPermissions.Values | Sort-Object { $_.Activities.Count } -Descending
    
    # Greedy set cover: pick permissions that cover the most activities
    $selectedPermissions = @()
    $coveredActivities = @{}
    
    foreach ($perm in $sortedPermissions) {
        # Check if this permission covers any new activities
        $newActivityCount = 0
        foreach ($activityId in $perm.Activities) {
            if (-not $coveredActivities.ContainsKey($activityId)) {
                $newActivityCount++
            }
        }
        
        if ($newActivityCount -gt 0) {
            # Add this permission
            $selectedPermissions += [PSCustomObject]@{
                Permission        = $perm.Permission
                ScopeType         = $perm.ScopeType
                IsLeastPrivilege  = $perm.IsLeastPrivilege
                ActivitiesCovered = $newActivityCount
            }
            
            # Mark activities as covered
            foreach ($activityId in $perm.Activities) {
                $coveredActivities[$activityId] = $true
            }
        }
        
        # Stop if all activities are covered
        if ($coveredActivities.Count -eq $matchedActivities.Count) {
            break
        }
    }
    
    return [PSCustomObject]@{
        OptimalPermissions  = $selectedPermissions
        UnmatchedActivities = $unmatchedActivities
        TotalActivities     = $activityPermissions.Count
        MatchedActivities   = $matchedActivities.Count
    }
}

# Load permission maps once at the start
Write-Host "Loading permission maps..." -ForegroundColor Cyan
$permissionMapv1 = Get-Content -Path ".\data\sample\permissions-v1.0.json" -Raw | ConvertFrom-Json
$permissionMapbeta = Get-Content -Path ".\data\sample\permissions-beta.json" -Raw | ConvertFrom-Json

# Process each app
$lightweightGroups | ForEach-Object {
    $app = $_
    
    Write-Host "`nAnalyzing: $($app.PrincipalName)" -ForegroundColor Cyan
    
    # Find least privileged permissions for each activity
    $activityPermissions = Find-LeastPrivilegedPermissions `
        -userActivity $app.UniqueActivity `
        -permissionMapv1 $permissionMapv1 `
        -permissionMapbeta $permissionMapbeta
    
    # Get optimal permission set
    $optimalSet = Get-OptimalPermissionSet -activityPermissions $activityPermissions
    
    # Add results to app object
    $app | Add-Member -MemberType NoteProperty -Name "ActivityPermissions" -Value $activityPermissions -Force
    $app | Add-Member -MemberType NoteProperty -Name "OptimalPermissions" -Value $optimalSet.OptimalPermissions -Force
    $app | Add-Member -MemberType NoteProperty -Name "UnmatchedActivities" -Value $optimalSet.UnmatchedActivities -Force
    
    # Compare with current permissions
    $currentPermissions = $app.AppRoles | Select-Object -ExpandProperty FriendlyName | Where-Object { $_ -ne $null }
    $optimalPermissionNames = $optimalSet.OptimalPermissions | Select-Object -ExpandProperty Permission -Unique
    
    $excessPermissions = $currentPermissions | Where-Object { $optimalPermissionNames -notcontains $_ }
    $missingPermissions = $optimalPermissionNames | Where-Object { $currentPermissions -notcontains $_ }
    
    $app | Add-Member -MemberType NoteProperty -Name "CurrentPermissions" -Value $currentPermissions -Force
    $app | Add-Member -MemberType NoteProperty -Name "ExcessPermissions" -Value $excessPermissions -Force
    $app | Add-Member -MemberType NoteProperty -Name "RequiredPermissions" -Value $missingPermissions -Force
    if ($optimalSet.UnmatchedActivities) {
        $matchedAllActivity = $false
    } else {
        $matchedAllActivity = $true
    }
    $app | Add-Member -MemberType NoteProperty -Name "MatchedAllActivity" -Value $matchedAllActivity -Force
    
    # Display summary
    Write-Host "  Matched Activities: $($optimalSet.MatchedActivities)/$($optimalSet.TotalActivities)" -ForegroundColor Green
    Write-Host "  Optimal Permissions: $($optimalSet.OptimalPermissions.Count)" -ForegroundColor Green
    Write-Host "  Current Permissions: $($currentPermissions.Count)" -ForegroundColor Yellow
    Write-Host "  Excess Permissions: $($excessPermissions.Count)" -ForegroundColor $(if ($excessPermissions.Count -gt 0) { "Red" }else { "Green" })
}


function New-PermissionAnalysisReport {
    param(
        [Parameter(Mandatory = $true)]
        [array]$AppData,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = ".\PermissionAnalysisReport.html",
        
        [Parameter(Mandatory = $false)]
        [string]$ReportTitle = "Microsoft Graph Permission Analysis Report"
    )
    
    # Convert data to JSON for embedding
    $jsonData = $AppData | ConvertTo-Json -Depth 10 -Compress
    
    # Properly escape for JavaScript - need to escape backslashes and quotes
    $jsonData = $jsonData.Replace('\', '\\').Replace('"', '\"').Replace([Environment]::NewLine, '\n')
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ReportTitle</title>
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
    <link href="https://cdn.datatables.net/1.11.5/css/jquery.dataTables.min.css" rel="stylesheet">
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.5.1/jquery.min.js"></script>
    <script src="https://cdn.datatables.net/1.11.5/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.2.2/js/dataTables.buttons.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.2.2/js/buttons.html5.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.1.3/jszip.min.js"></script>
    <link href="https://cdn.datatables.net/buttons/2.2.2/css/buttons.dataTables.min.css" rel="stylesheet">
    <style>
        .status-badge {
            display: inline-block;
            padding: 0.25rem 0.75rem;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 600;
        }
        .status-good { background-color: #D1FAE5; color: #065F46; }
        .status-warning { background-color: #FEF3C7; color: #92400E; }
        .status-danger { background-color: #FEE2E2; color: #991B1B; }
    </style>
</head>
<body class="bg-gray-100 min-h-screen">
    <div class="container mx-auto px-4 py-8">
        <!-- Header -->
        <div class="bg-white rounded-lg shadow-lg p-6 mb-6">
            <h1 class="text-3xl font-bold text-gray-800 mb-2">$ReportTitle</h1>
            <p class="text-gray-600">Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
            <div class="mt-4 grid grid-cols-1 md:grid-cols-4 gap-4">
                <div class="bg-blue-50 rounded-lg p-4">
                    <div class="text-blue-600 text-sm font-semibold">Total Applications</div>
                    <div class="text-2xl font-bold text-blue-900" id="totalApps">0</div>
                </div>
                <div class="bg-green-50 rounded-lg p-4">
                    <div class="text-green-600 text-sm font-semibold">Fully Matched All Activity To Permissions</div>
                    <div class="text-2xl font-bold text-green-900" id="fullyMatched">0</div>
                </div>
                <div class="bg-yellow-50 rounded-lg p-4">
                    <div class="text-yellow-600 text-sm font-semibold">With Excessive Permissions</div>
                    <div class="text-2xl font-bold text-yellow-900" id="withExcess">0</div>
                </div>
                <div class="bg-red-50 rounded-lg p-4">
                    <div class="text-red-600 text-sm font-semibold">Unmatched Activities</div>
                    <div class="text-2xl font-bold text-red-900" id="withUnmatched">0</div>
                </div>
            </div>
        </div>

        <!-- Filters -->
        <div class="bg-white rounded-lg shadow-lg p-6 mb-6">
            <h2 class="text-xl font-bold text-gray-800 mb-4">Filters</h2>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Status</label>
                    <select id="statusFilter" class="w-full border border-gray-300 rounded-lg p-2">
                        <option value="">All</option>
                        <option value="good">Optimal (No Excess)</option>
                        <option value="warning">Has Excess Permissions</option>
                        <option value="danger">Unmatched Activities</option>
                    </select>
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Activity Status</label>
                    <select id="activityFilter" class="w-full border border-gray-300 rounded-lg p-2">
                        <option value="">All</option>
                        <option value="yes">Has Activity</option>
                        <option value="no">No Activity</option>
                    </select>
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Search</label>
                    <input type="text" id="searchBox" class="w-full border border-gray-300 rounded-lg p-2" placeholder="Search by app name...">
                </div>
            </div>
        </div>

        <!-- Results Table -->
        <div class="bg-white rounded-lg shadow-lg p-6">
            <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-bold text-gray-800">Application Permission Analysis</h2>
                <button id="exportBtn" class="bg-blue-500 hover:bg-blue-600 text-white font-semibold py-2 px-4 rounded-lg">
                    Export to CSV
                </button>
            </div>
            <div class="overflow-x-auto">
                <table id="resultsTable" class="min-w-full bg-white display stripe hover">
                    <thead class="bg-gray-50">
                        <tr>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Application Name</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Current Permissions</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Optimal Permissions</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Excess Permissions</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Missing Permissions</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Activities</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Details</th>
                        </tr>
                    </thead>
                    <tbody id="tableBody">
                        <!-- Data will be populated here -->
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- Details Modal -->
    <div id="detailsModal" class="hidden fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
        <div class="relative top-20 mx-auto p-5 border w-11/12 max-w-4xl shadow-lg rounded-lg bg-white">
            <div class="flex justify-between items-center mb-4">
                <h3 class="text-2xl font-bold text-gray-900" id="modalTitle">Application Details</h3>
                <button id="closeModal" class="text-gray-400 hover:text-gray-600 text-3xl font-bold">&times;</button>
            </div>
            <div id="modalContent" class="mt-4 max-h-96 overflow-y-auto">
                <!-- Modal content will be populated here -->
            </div>
        </div>
    </div>

    <script>
        const appData = JSON.parse("$jsonData");
        let dataTable;
        let originalData = [];

        jQuery(document).ready(function() {
            console.log('Loaded', appData.length, 'applications');
            
            // Calculate statistics
            const stats = {
                total: appData.length,
                fullyMatched: appData.filter(app => app.MatchedAllActivity && (!app.ExcessPermissions || app.ExcessPermissions.length === 0)).length,
                withExcess: appData.filter(app => app.ExcessPermissions && app.ExcessPermissions.length > 0).length,
                withUnmatched: appData.filter(app => !app.MatchedAllActivity).length
            };
            
            jQuery('#totalApps').text(stats.total);
            jQuery('#fullyMatched').text(stats.fullyMatched);
            jQuery('#withExcess').text(stats.withExcess);
            jQuery('#withUnmatched').text(stats.withUnmatched);
            
            // Prepare data for DataTables
            originalData = prepareTableData(appData);
            
            // Initialize DataTable with proper column definitions
            dataTable = jQuery('#resultsTable').DataTable({
                data: originalData,
                pageLength: 25,
                order: [[0, 'asc']],
                columns: [
                    { 
                        data: 'appName',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                return '<div class="font-medium text-gray-900">' + data + '</div><div class="text-xs text-gray-500">' + row.appId + '</div>';
                            }
                            return data;
                        }
                    },
                    { 
                        data: 'status',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                return getStatusBadge(data);
                            }
                            return data;
                        }
                    },
                    { 
                        data: 'currentPerms',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                let html = '<span class="font-semibold">' + data.length + '</span>';
                                if (data.length > 0) {
                                    html += '<br><span class="text-xs text-gray-500">' + data.slice(0, 2).join(', ') + (data.length > 2 ? '...' : '') + '</span>';
                                }
                                return html;
                            }
                            return data.length;
                        }
                    },
                    { 
                        data: 'optimalPerms',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                let html = '<span class="font-semibold text-green-600">' + data.length + '</span>';
                                if (data.length > 0) {
                                    const names = data.map(p => p.Permission);
                                    html += '<br><span class="text-xs text-gray-500">' + names.slice(0, 2).join(', ') + (names.length > 2 ? '...' : '') + '</span>';
                                }
                                return html;
                            }
                            return data.length;
                        }
                    },
                    { 
                        data: 'excessPerms',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                let html = '<span class="font-semibold ' + (data.length > 0 ? 'text-red-600' : 'text-green-600') + '">' + data.length + '</span>';
                                if (data.length > 0) {
                                    html += '<br><span class="text-xs text-red-500">' + data.slice(0, 2).join(', ') + (data.length > 2 ? '...' : '') + '</span>';
                                }
                                return html;
                            }
                            return data.length;
                        }
                    },
                    { 
                        data: 'missingPerms',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                let html = '<span class="font-semibold ' + (data.length > 0 ? 'text-yellow-600' : 'text-green-600') + '">' + data.length + '</span>';
                                if (data.length > 0) {
                                    html += '<br><span class="text-xs text-yellow-600">' + data.slice(0, 2).join(', ') + (data.length > 2 ? '...' : '') + '</span>';
                                }
                                return html;
                            }
                            return data.length;
                        }
                    },
                    { 
                        data: 'activityCount',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                let html = '<span class="font-semibold">' + data + '</span>';
                                html += data > 0 ? '<span class="text-xs text-gray-500"><br>endpoints</span>' : '<span class="text-xs text-gray-400"><br>No activity</span>';
                                return html;
                            }
                            return data;
                        }
                    },
                    { 
                        data: 'index',
                        orderable: false,
                        render: function(data, type, row) {
                            return '<button onclick="showDetails(' + data + ')" class="bg-blue-500 hover:bg-blue-600 text-white font-semibold py-1 px-3 rounded text-xs">View Details</button>';
                        }
                    }
                ]
            });
            
            // Filters with custom implementation
            jQuery('#statusFilter').change(function() {
                const value = jQuery(this).val();
                dataTable.column(1).search(value, false, false).draw();
            });
            
            jQuery('#activityFilter').change(function() {
                const value = jQuery(this).val();
                if (value === 'yes') {
                    dataTable.column(6).search('^[1-9]', true, false).draw();
                } else if (value === 'no') {
                    dataTable.column(6).search('^0$', true, false).draw();
                } else {
                    dataTable.column(6).search('').draw();
                }
            });
            
            jQuery('#searchBox').keyup(function() {
                dataTable.search(jQuery(this).val()).draw();
            });
            
            // Export button
            jQuery('#exportBtn').click(function() {
                exportToCSV();
            });
            
            // Modal handlers
            jQuery('#closeModal').click(function() {
                jQuery('#detailsModal').addClass('hidden');
            });
            
            jQuery(window).click(function(event) {
                if (jQuery(event.target).is('#detailsModal')) {
                    jQuery('#detailsModal').addClass('hidden');
                }
            });
        });
        
        function prepareTableData(data) {
            return data.map((app, index) => {
                const currentPerms = Array.isArray(app.CurrentPermissions) ? app.CurrentPermissions : (app.CurrentPermissions ? [app.CurrentPermissions] : []);
                const optimalPerms = Array.isArray(app.OptimalPermissions) ? app.OptimalPermissions : (app.OptimalPermissions ? [app.OptimalPermissions] : []);
                const excessPerms = Array.isArray(app.ExcessPermissions) ? app.ExcessPermissions : (app.ExcessPermissions ? [app.ExcessPermissions] : []);
                const missingPerms = Array.isArray(app.MissingPermissions) ? app.MissingPermissions : (app.MissingPermissions ? [app.MissingPermissions] : []);
                const activityCount = app.UniqueActivity ? (Array.isArray(app.UniqueActivity) ? app.UniqueActivity.length : 1) : 0;
                
                return {
                    appName: app.PrincipalName || 'N/A',
                    appId: app.PrincipalId || 'N/A',
                    status: getStatus(app),
                    currentPerms: currentPerms,
                    optimalPerms: optimalPerms,
                    excessPerms: excessPerms,
                    missingPerms: missingPerms,
                    activityCount: activityCount,
                    index: index
                };
            });
        }
        
        function getStatus(app) {
            if (!app.MatchedAllActivity) return 'danger';
            if (app.ExcessPermissions && ((Array.isArray(app.ExcessPermissions) && app.ExcessPermissions.length > 0) || (!Array.isArray(app.ExcessPermissions) && app.ExcessPermissions))) return 'warning';
            return 'good';
        }
        
        function getStatusBadge(status) {
            const badges = {
                good: '<span class="status-badge status-good">&#10003; Optimal</span>',
                warning: '<span class="status-badge status-warning">&#9888; Has Excess</span>',
                danger: '<span class="status-badge status-danger">&#10007; Unmatched</span>'
            };
            return badges[status] || '';
        }
        
        function showDetails(index) {
            const app = appData[index];
            jQuery('#modalTitle').text(app.PrincipalName || 'Application Details');
            
            let content = '<div class="space-y-4"><div class="border-b pb-4"><h4 class="font-bold text-lg mb-2">Application Information</h4>';
            content += '<p><span class="font-semibold">Principal ID:</span> ' + app.PrincipalId + '</p>';
            content += '<p><span class="font-semibold">Total App Roles:</span> ' + app.AppRoleCount + '</p>';
            content += '<p><span class="font-semibold">Matched All Activities:</span> ' + (app.MatchedAllActivity ? '&#10003; Yes' : '&#10007; No') + '</p></div>';
            
            const currentPerms = Array.isArray(app.CurrentPermissions) ? app.CurrentPermissions : (app.CurrentPermissions ? [app.CurrentPermissions] : []);
            if (currentPerms.length > 0) {
                content += '<div class="border-b pb-4"><h4 class="font-bold text-lg mb-2">Current Permissions (' + currentPerms.length + ')</h4><ul class="list-disc list-inside text-sm space-y-1">';
                currentPerms.forEach(p => { content += '<li>' + p + '</li>'; });
                content += '</ul></div>';
            }
            
            const optimalPerms = Array.isArray(app.OptimalPermissions) ? app.OptimalPermissions : [];
            if (optimalPerms.length > 0) {
                content += '<div class="border-b pb-4"><h4 class="font-bold text-lg mb-2 text-green-600">Optimal Permissions (' + optimalPerms.length + ')</h4><ul class="list-disc list-inside text-sm space-y-1">';
                optimalPerms.forEach(p => { content += '<li><span class="font-medium">' + p.Permission + '</span> (Covers ' + p.ActivitiesCovered + ' activities)</li>'; });
                content += '</ul></div>';
            }
            
            const excessPerms = Array.isArray(app.ExcessPermissions) ? app.ExcessPermissions : (app.ExcessPermissions ? [app.ExcessPermissions] : []);
            if (excessPerms.length > 0) {
                content += '<div class="border-b pb-4"><h4 class="font-bold text-lg mb-2 text-red-600">Excess Permissions (' + excessPerms.length + ')</h4><ul class="list-disc list-inside text-sm space-y-1 text-red-600">';
                excessPerms.forEach(p => { content += '<li>' + p + '</li>'; });
                content += '</ul></div>';
            }
            
            const missingPerms = Array.isArray(app.MissingPermissions) ? app.MissingPermissions : (app.MissingPermissions ? [app.MissingPermissions] : []);
            if (missingPerms.length > 0) {
                content += '<div class="border-b pb-4"><h4 class="font-bold text-lg mb-2 text-yellow-600">Missing Permissions (' + missingPerms.length + ')</h4><ul class="list-disc list-inside text-sm space-y-1 text-yellow-600">';
                missingPerms.forEach(p => { content += '<li>' + p + '</li>'; });
                content += '</ul></div>';
            }
            
            const activities = Array.isArray(app.UniqueActivity) ? app.UniqueActivity : (app.UniqueActivity ? [app.UniqueActivity] : []);
            if (activities.length > 0) {
                content += '<div><h4 class="font-bold text-lg mb-2">API Activities (' + activities.length + ')</h4><div class="max-h-64 overflow-y-auto"><table class="min-w-full text-sm"><thead class="bg-gray-50 sticky top-0"><tr><th class="px-2 py-2 text-left">Method</th><th class="px-2 py-2 text-left">Endpoint</th></tr></thead><tbody>';
                activities.forEach(a => { content += '<tr class="border-b"><td class="px-2 py-2 font-mono text-xs">' + a.Method + '</td><td class="px-2 py-2 font-mono text-xs break-all">' + a.Uri + '</td></tr>'; });
                content += '</tbody></table></div></div>';
            }
            
            const unmatched = Array.isArray(app.UnmatchedActivities) ? app.UnmatchedActivities : [];
            if (unmatched.length > 0) {
                content += '<div class="bg-red-50 p-4 rounded"><h4 class="font-bold text-lg mb-2 text-red-600">Unmatched Activities (' + unmatched.length + ')</h4><ul class="list-disc list-inside text-sm space-y-1 text-red-700">';
                unmatched.forEach(a => { content += '<li>' + a.Method + ' ' + a.Path + '</li>'; });
                content += '</ul></div>';
            }
            
            content += '</div>';
            jQuery('#modalContent').html(content);
            jQuery('#detailsModal').removeClass('hidden');
        }
        
                function exportToCSV() {
                    let csv = 'Application Name;Principal ID;Status;Current Permissions;Current Permission Count;Optimal Permissions;Optimal Permission Count;Excess Permissions;Excess Permission Count;Missing Permissions;Missing Permission Count;Activity Count;Matched All Activities\n';
                    
                    appData.forEach(app => {
                        const status = getStatus(app);
                        const currentPerms = Array.isArray(app.CurrentPermissions) ? app.CurrentPermissions : (app.CurrentPermissions ? [app.CurrentPermissions] : []);
                        const optimalPerms = Array.isArray(app.OptimalPermissions) ? app.OptimalPermissions : [];
                        const excessPerms = Array.isArray(app.ExcessPermissions) ? app.ExcessPermissions : (app.ExcessPermissions ? [app.ExcessPermissions] : []);
                        const missingPerms = Array.isArray(app.MissingPermissions) ? app.MissingPermissions : (app.MissingPermissions ? [app.MissingPermissions] : []);
                        const activities = Array.isArray(app.UniqueActivity) ? app.UniqueActivity : (app.UniqueActivity ? [app.UniqueActivity] : []);
                        
                        const row = [
                            '"' + (app.PrincipalName || '').replace(/"/g, '""') + '"',
                            '"' + (app.PrincipalId || '').replace(/"/g, '""') + '"',
                            status,
                            '"' + currentPerms.join(', ').replace(/"/g, '""') + '"',
                            currentPerms.length,
                            '"' + optimalPerms.map(p => p.Permission).join(', ').replace(/"/g, '""') + '"',
                            optimalPerms.length,
                            '"' + excessPerms.join(', ').replace(/"/g, '""') + '"',
                            excessPerms.length,
                            '"' + missingPerms.join(', ').replace(/"/g, '""') + '"',
                            missingPerms.length,
                            activities.length,
                            app.MatchedAllActivity ? 'Yes' : 'No'
                        ];
                        csv += row.join(';') + '\n';
                    });
                    
                    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
                    const link = document.createElement('a');
                    const url = URL.createObjectURL(blob);
                    link.setAttribute('href', url);
                    link.setAttribute('download', 'permission_analysis_' + new Date().getTime() + '.csv');
                    link.style.visibility = 'hidden';
                    document.body.appendChild(link);
                    link.click();
                    document.body.removeChild(link);
                }
    </script>
</body>
</html>
"@

    # Write the HTML to file
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "Report generated successfully: $OutputPath" -ForegroundColor Green
    
    # Open in default browser
    Start-Process $OutputPath
}

# Usage example:
# New-PermissionAnalysisReport -AppData $lightweightGroups -OutputPath ".\PermissionReport.html"


New-PermissionAnalysisReport -AppData $lightweightGroups -OutputPath ".\report.html"