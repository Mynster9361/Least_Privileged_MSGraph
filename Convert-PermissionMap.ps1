param (
    [Parameter(Mandatory=$true)]
    [string]$DocsPath,

    [string]$JsonOutputPath = "graph_api_permissions_map.json",
    [string]$MappingJsonOutputPath = "graph_api_permissions_friendly_names.json",
    [string]$RoleEndpointMappingPath = "graph_api_permissions_endpoints.json",
    [string[]]$Versions = @("v1.0", "beta"),

    # Parameter for permissions reference file
    [string]$PermissionsReferencePath
)

# Base paths
$apiReferencePath = Join-Path -Path $DocsPath -ChildPath "api-reference"
Write-Host "API Reference path: $apiReferencePath"

# Default permissions reference path if not provided
if (-not $PermissionsReferencePath) {
    $PermissionsReferencePath = Join-Path -Path $DocsPath -ChildPath "concepts\permissions-reference.md"
}

function Extract-PermissionIdentifiers {
    param (
        [string]$permissionsRefPath
    )

    Write-Host "Extracting permission identifiers from $permissionsRefPath"

    if (-not (Test-Path -Path $permissionsRefPath)) {
        Write-Warning "Permissions reference file not found: $permissionsRefPath"
        return @{}
    }

    $content = Get-Content -Path $permissionsRefPath -Raw

    # New regex pattern that properly matches the permissions reference format
    $permissionSectionPattern = [regex]::new('### ([A-Za-z0-9._]+)[\s\S]*?Identifier\s*\|\s*([a-f0-9-]+)\s*\|\s*([a-f0-9-]+)\s*\|', [System.Text.RegularExpressions.RegexOptions]::Singleline)

    $identifiers = [ordered]@{}
    $matches = $permissionSectionPattern.Matches($content)

    Write-Host "Found $($matches.Count) permission matches in reference file"

    # Sort matches by permission name for consistent ordering
    $sortedMatches = $matches | Sort-Object { $_.Groups[1].Value }

    foreach ($match in $sortedMatches) {
        $permissionName = $match.Groups[1].Value
        $appId = $match.Groups[2].Value
        $delegatedId = $match.Groups[3].Value

        Write-Verbose "Found permission: $permissionName, App: $appId, Delegated: $delegatedId"

        $identifiers[$permissionName] = [ordered]@{
            "ApplicationId" = $appId
            "DelegatedId" = $delegatedId
        }
    }

    Write-Host "Extracted $($identifiers.Count) permission identifiers"
    return $identifiers
}

function Export-PermissionMappings {
    param (
        [hashtable]$permissionIdentifiers,
        [string]$outputPath
    )

    Write-Host "Exporting permission mappings to $outputPath"

    $mappings = [System.Collections.ArrayList]::new()

    # Sort permission names for consistent output
    $sortedPermissionNames = $permissionIdentifiers.Keys | Sort-Object

    foreach ($permissionName in $sortedPermissionNames) {
        $mapping = [ordered]@{
            "Role_Name" = $permissionName
            "Application_Identifier" = $permissionIdentifiers[$permissionName].ApplicationId
            "DelegatedWork_Identifier" = $permissionIdentifiers[$permissionName].DelegatedId
        }

        [void]$mappings.Add($mapping)
    }

    # Convert to JSON with consistent formatting
    $jsonOutput = $mappings | ConvertTo-Json -Depth 1 -Compress:$false
    $jsonOutput | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline
    Write-Host "Exported $($mappings.Count) permission mappings"
}

function Extract-HttpRequests {
    param (
        [string]$content
    )

    $httpPattern = [regex]::new('## HTTP request.*?```http(.*?)```', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $match = $httpPattern.Match($content)

    if (!$match.Success) {
        return @()
    }

    $httpBlock = $match.Groups[1].Value
    $endpoints = @()

    # List of valid HTTP methods
    $validMethods = @('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS')

    foreach ($line in $httpBlock -split "`n") {
        $line = $line.Trim()

        # Skip empty lines, comments, and non-HTTP method lines
        if (!$line -or $line.StartsWith('//') -or $line.StartsWith('#')) {
            continue
        }

        # Check if line starts with a valid HTTP method
        $parts = $line -split ' ', 2
        if ($parts.Count -eq 2 -and $validMethods -contains $parts[0]) {
            $method = $parts[0]
            $path = $parts[1]
            $endpoints += [ordered]@{
                "method" = $method
                "path" = $path
            }
        }
    }

    return $endpoints
}

function Extract-ExampleUrl {
    param (
        [string]$content
    )

    $examplePattern = [regex]::new('```msgraph-interactive\s+((?:GET|POST|PATCH|PUT|DELETE).*?https://graph\.microsoft\.com/.*?)(?:\r?\n|$)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $match = $examplePattern.Match($content)

    if ($match.Success) {
        $exampleLine = $match.Groups[1].Value.Trim()
        # Extract just the URL part (after the HTTP method)
        if ($exampleLine -match '(?:GET|POST|PATCH|PUT|DELETE)\s+(https://.*?)(?:\s|$)') {
            return $matches[1].Trim()
        }
    }

    return $null
}

function Extract-PermissionsInclude {
    param (
        [string]$content
    )

    $permissionPattern = [regex]::new('<!-- \{ "blockType": "permissions", "name": "(.*?)" \} -->\s*\[!INCLUDE \[permissions-table\]\((.*?)\)\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $match = $permissionPattern.Match($content)

    if ($match.Success) {
        $operationName = $match.Groups[1].Value
        $permissionsPath = $match.Groups[2].Value
        return [ordered]@{
            "operationName" = $operationName
            "permissionsPath" = $permissionsPath
        }
    }

    return $null
}

function Parse-PermissionsTable {
    param (
        [string]$content
    )

    # Simple markdown table parser - extract rows
    $tableRows = @()
    $inTable = $false

    foreach ($line in $content -split "`n") {
        $line = $line.Trim()

        # Skip header/metadata at the top
        if ($line -match "^---" -and !$inTable) {
            $inTable = $true
            continue
        }

        if ($line -match "^---" -and $inTable) {
            $inTable = $false
            continue
        }

        # Skip non-table content
        if (!$line -or $line -match "^#" -or $line -match "^>" -or $line -match "^ms\." -or $line -match "description") {
            continue
        }

        # Table rows start with | and end with |
        if ($line -match "^\|.*\|$") {
            $tableRows += $line
        }
    }

    # Need at least header row and one data row
    if ($tableRows.Count -lt 2) {
        return @()
    }

    # Skip the header row and the separator row
    $results = @()

    # Process data rows (skip first 2 rows - header and separator)
    for ($i = 2; $i -lt $tableRows.Count; $i++) {
        $row = $tableRows[$i]
        $cells = $row -split '\|' | Where-Object { $_ } | ForEach-Object { $_.Trim() }

        if ($cells.Count -ge 3) {
            $permissionType = $cells[0]
            $leastPrivileged = $cells[1] -split ',' | ForEach-Object { $_.Trim() } | Sort-Object
            $higherPrivileged = $cells[2] -split ',' | ForEach-Object { $_.Trim() } | Sort-Object

            $results += [ordered]@{
                "permission_type" = $permissionType
                "least_privileged" = $leastPrivileged
                "higher_privileged" = $higherPrivileged
            }
        }
    }

    return $results
}

function Process-ApiFiles {
    param (
        [string]$version,
        [hashtable]$permissionIdentifiers = @{}
    )

    $versionPath = Join-Path -Path $apiReferencePath -ChildPath $version
    $apiPath = Join-Path -Path $versionPath -ChildPath "api"

    Write-Host "Processing API files in $apiPath"

    # Get all API markdown files recursively
    $files = Get-ChildItem -Path $apiPath -Filter "*.md" -Recurse -File

    $results = [System.Collections.ArrayList]::new()
    $processedCount = 0
    $totalFiles = $files.Count

    Write-Host "Found $totalFiles files for $version..."

    foreach ($file in $files) {
        $processedCount++
        if ($processedCount % 50 -eq 0) {
            Write-Progress -Activity "Processing $version files" -Status "$processedCount of $totalFiles" -PercentComplete (($processedCount / $totalFiles) * 100)
        }

        $filePath = $file.FullName
        $relativePath = $file.FullName.Replace($DocsPath, '').TrimStart('\', '/')

        $content = Get-Content -Path $filePath -Raw
        if (!$content) { continue }

        $endpoints = Extract-HttpRequests -content $content
        if (!$endpoints -or $endpoints.Count -eq 0) { continue }

        $permissionsInfo = Extract-PermissionsInclude -content $content
        if (!$permissionsInfo) { continue }

        $operationName = $permissionsInfo.operationName
        $permissionsRelativePath = $permissionsInfo.permissionsPath

        # Resolve the permissions path relative to the current file
        $fileDir = Split-Path -Parent $filePath
        $permissionsFullPath = Join-Path -Path $fileDir -ChildPath $permissionsRelativePath

        if (!(Test-Path $permissionsFullPath)) {
            # Try with explicit includes directory
            $includesDir = Join-Path -Path $versionPath -ChildPath "includes"
            $permissionsFullPath = Join-Path -Path $includesDir -ChildPath $permissionsRelativePath.TrimStart('.', '/', '\')
        }

        if (!(Test-Path $permissionsFullPath)) {
            Write-Warning "Permissions file not found: $permissionsRelativePath for $filePath"
            continue
        }

        $permissionsContent = Get-Content -Path $permissionsFullPath -Raw
        if (!$permissionsContent) { continue }

        $permissions = Parse-PermissionsTable -content $permissionsContent

        # Map endpoints to permissions
        foreach ($endpoint in $endpoints) {
            $delegatedWork = $null
            $delegatedPersonal = $null
            $application = $null
            foreach ($perm in $permissions) {
                switch ($perm.permission_type) {
                    "Delegated (work or school account)" {
                        $delegatedWork = $perm
                        break
                    }
                    "Delegated (personal Microsoft account)" {
                        $delegatedPersonal = $perm
                        break
                    }
                    "Application" {
                        $application = $perm
                        break
                    }
                }
            }

            # Try to extract example URL directly from the markdown
            $exampleUrl = Extract-ExampleUrl -content $content

            $resultObject = [ordered]@{
                "path" = if ($endpoint.path) { $endpoint.path } else { "" }
                "version" = $version
                "method" = if ($endpoint.method) { $endpoint.method } else { "" }
                "operation_name" = $operationName
                "full_example_url" = if ($exampleUrl) { $exampleUrl } else { "https://graph.microsoft.com/$($version)$($endpoint.path)" }
                "example_from_docs" = [bool]$exampleUrl
                "DelegatedWork_Least" = if ($delegatedWork) { $delegatedWork.least_privileged } else { @() }
                "DelegatedWork_Higher" = if ($delegatedWork) { $delegatedWork.higher_privileged } else { @() }
                "DelegatedPersonal_Least" = if ($delegatedPersonal) { $delegatedPersonal.least_privileged } else { @() }
                "DelegatedPersonal_Higher" = if ($delegatedPersonal) { $delegatedPersonal.higher_privileged } else { @() }
                "Application_Least" = if ($application) { $application.least_privileged } else { @() }
                "Application_Higher" = if ($application) { $application.higher_privileged } else { @() }
            }

            [void]$results.Add($resultObject)
        }
    }

    Write-Progress -Activity "Processing $version files" -Completed
    return $results
}

function Create-RoleToEndpointMapping {
    param(
        [array]$apiMappings
    )

    Write-Host "Creating role-to-endpoint mappings..."

    # Use regular hashtable for ContainsKey method, we'll sort at the end
    $roleEndpointMap = @{}

    # Process all the API mappings and collect all unique permissions first
    $allPermissions = [System.Collections.ArrayList]::new()
    
    foreach ($mapping in $apiMappings) {
        # Collect all permissions from all categories
        $permissionCategories = @(
            @{Permissions = $mapping.DelegatedWork_Least; Type = "Delegated"},
            @{Permissions = $mapping.Application_Least; Type = "Application"},
            @{Permissions = $mapping.DelegatedWork_Higher; Type = "Delegated"},
            @{Permissions = $mapping.Application_Higher; Type = "Application"}
        )

        foreach ($category in $permissionCategories) {
            if ($category.Permissions) {
                foreach ($permission in $category.Permissions) {
                    $permission = $permission.Trim()
                    if ($permission -ne "Not supported." -and $permission -ne "Not available." -and ![string]::IsNullOrWhiteSpace($permission)) {
                        [void]$allPermissions.Add(@{Permission = $permission; Type = $category.Type})
                    }
                }
            }
        }
    }

    # Get unique permissions and sort them deterministically
    $uniquePermissions = $allPermissions | Sort-Object -Property Type, Permission -Unique

    # Initialize the hashtable with sorted keys
    foreach ($permEntry in $uniquePermissions) {
        $key = $permEntry.Permission
        if (-not $roleEndpointMap.ContainsKey($key)) {
            $roleEndpointMap[$key] = @{
                "Role" = $key
                "Type" = $permEntry.Type
                "Endpoints" = [System.Collections.ArrayList]::new()
            }
        }
    }

    # Now process mappings and add endpoints
    foreach ($mapping in $apiMappings) {
        # Process each permission category
        $permissionCategories = @(
            @{Permissions = $mapping.DelegatedWork_Least; Type = "Delegated"},
            @{Permissions = $mapping.Application_Least; Type = "Application"},
            @{Permissions = $mapping.DelegatedWork_Higher; Type = "Delegated"},
            @{Permissions = $mapping.Application_Higher; Type = "Application"}
        )

        foreach ($category in $permissionCategories) {
            if ($category.Permissions) {
                foreach ($permission in $category.Permissions) {
                    $permission = $permission.Trim()
                    if ($permission -eq "Not supported." -or $permission -eq "Not available." -or [string]::IsNullOrWhiteSpace($permission)) {
                        continue
                    }

                    if ($roleEndpointMap.ContainsKey($permission)) {
                        # Create endpoint object with consistent property ordering
                        $endpoint = [ordered]@{
                            "Method" = if ($mapping.method) { $mapping.method } else { "" }
                            "OperationName" = if ($mapping.operation_name) { $mapping.operation_name } else { "" }
                            "Path" = if ($mapping.path) { $mapping.path } else { "" }
                            "Version" = if ($mapping.version) { $mapping.version } else { "" }
                        }

                        # Only add if we have meaningful data
                        if ($endpoint.Path -or $endpoint.Method -or $endpoint.OperationName) {
                            [void]$roleEndpointMap[$permission].Endpoints.Add($endpoint)
                        }
                    }
                }
            }
        }
    }

    # Convert to final result with consistent ordering
    $result = [System.Collections.ArrayList]::new()

    # Sort the keys for consistent output
    $sortedKeys = $roleEndpointMap.Keys | Sort-Object

    foreach ($key in $sortedKeys) {
        # Remove duplicates and sort endpoints deterministically
        $uniqueEndpoints = [System.Collections.ArrayList]::new()
        $seenEndpoints = @{}
        
        foreach ($endpoint in $roleEndpointMap[$key].Endpoints) {
            # Create a unique identifier for the endpoint
            $uniqueKey = "$($endpoint.Version)|$($endpoint.Path)|$($endpoint.Method)|$($endpoint.OperationName)"
            
            if (-not $seenEndpoints.ContainsKey($uniqueKey)) {
                $seenEndpoints[$uniqueKey] = $true
                [void]$uniqueEndpoints.Add($endpoint)
            }
        }
        
        # Sort endpoints deterministically
        $sortedEndpoints = $uniqueEndpoints | Sort-Object -Property Version, Path, Method, OperationName

        # Create final object with consistent property ordering
        $roleObject = [ordered]@{
            "Endpoints" = $sortedEndpoints
            "Role" = $roleEndpointMap[$key].Role
            "Type" = $roleEndpointMap[$key].Type
        }

        [void]$result.Add($roleObject)
    }

    return $result
}

# Main execution
$allResults = [System.Collections.ArrayList]::new()

# Extract permission identifiers
$permissionIdentifiers = Extract-PermissionIdentifiers -permissionsRefPath $PermissionsReferencePath

# Export the permission mappings to a separate file
Export-PermissionMappings -permissionIdentifiers $permissionIdentifiers -outputPath $MappingJsonOutputPath

foreach ($version in $Versions) {
    Write-Host "Starting to process $version API files..."
    $versionResults = Process-ApiFiles -version $version -permissionIdentifiers $permissionIdentifiers
    foreach ($result in $versionResults) {
        [void]$allResults.Add($result)
    }
    Write-Host "Completed processing $version API files. Found $($versionResults.Count) mappings."
}

# Save as JSON with consistent sorting
$sortedResults = $allResults | Sort-Object -Property version, path, method, operation_name
$jsonOutput = $sortedResults | ConvertTo-Json -Depth 4 -Compress:$false
$jsonOutput | Out-File -FilePath $JsonOutputPath -Encoding UTF8 -NoNewline
Write-Host "Saved JSON output to $JsonOutputPath"

# Create and save the role-to-endpoint mappings with deterministic sorting
$roleEndpointMappings = Create-RoleToEndpointMapping -apiMappings $allResults
$jsonOutput = $roleEndpointMappings | ConvertTo-Json -Depth 4 -Compress:$false
$jsonOutput | Out-File -FilePath $RoleEndpointMappingPath -Encoding UTF8 -NoNewline
Write-Host "Saved role-to-endpoint mapping to $RoleEndpointMappingPath"