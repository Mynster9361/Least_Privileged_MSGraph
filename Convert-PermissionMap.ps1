param (
    [Parameter(Mandatory=$true)]
    [string]$DocsPath,

    [string]$JsonOutputPath = "graph_api_permissions_map.json",
    [string[]]$Versions = @("v1.0", "beta"),

    # New parameter for permissions reference file
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

    # Regular expression to extract permission sections
    $permissionSectionPattern = [regex]::new('### ([A-Za-z0-9\.\_]+)\s+\|\s+Category\s+\|\s+Application\s+\|\s+Delegated\s+\|(?:.+?)\|\s+Identifier\s+\|\s+([a-f0-9\-]+)\s+\|\s+([a-f0-9\-]+)\s+\|', [System.Text.RegularExpressions.RegexOptions]::Singleline)

    $identifiers = @{}
    $matches = $permissionSectionPattern.Matches($content)

    foreach ($match in $matches) {
        $permissionName = $match.Groups[1].Value
        $appId = $match.Groups[2].Value
        $delegatedId = $match.Groups[3].Value

        $identifiers[$permissionName] = @{
            "ApplicationId" = $appId
            "DelegatedId" = $delegatedId
        }
    }

    Write-Host "Extracted $($identifiers.Count) permission identifiers"
    return $identifiers
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
            $endpoints += @{
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
        return @{
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
            $leastPrivileged = $cells[1] -split ',' | ForEach-Object { $_.Trim() }
            $higherPrivileged = $cells[2] -split ',' | ForEach-Object { $_.Trim() }

            $results += @{
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

    $results = @()
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

            # Add identifiers for permissions
            $delegatedWorkIdentifiers = @()
            $applicationIdentifiers = @()

            # Process delegated work permissions
            if ($delegatedWork -and $delegatedWork.least_privileged) {
                foreach ($perm in $delegatedWork.least_privileged) {
                    if ($permissionIdentifiers.ContainsKey($perm)) {
                        $delegatedWorkIdentifiers += $permissionIdentifiers[$perm].DelegatedId
                    }
                }
            }

            # Process application permissions
            if ($application -and $application.least_privileged) {
                foreach ($perm in $application.least_privileged) {
                    if ($permissionIdentifiers.ContainsKey($perm)) {
                        $applicationIdentifiers += $permissionIdentifiers[$perm].ApplicationId
                    }
                }
            }

            $results += [PSCustomObject]@{
                "Application_Identifiers" = $applicationIdentifiers
                "DelegatedWork_Identifiers" = $delegatedWorkIdentifiers
                "path" = $endpoint.path
                "version" = $version
                "method" = $endpoint.method
                "operation_name" = $operationName
                "full_example_url" = if ($exampleUrl) { $exampleUrl } else { "https://graph.microsoft.com/$($version)$($endpoint.path)" }
                "example_from_docs" = [bool]$exampleUrl
                "DelegatedWork_Least" = $delegatedWork.least_privileged
                "DelegatedWork_Higher" = $delegatedWork.higher_privileged
                "DelegatedPersonal_Least" = $delegatedPersonal.least_privileged
                "DelegatedPersonal_Higher" = $delegatedPersonal.higher_privileged
                "Application_Least" = $application.least_privileged
                "Application_Higher" = $application.higher_privileged
            }
        }
    }

    Write-Progress -Activity "Processing $version files" -Completed
    return $results
}

# Main execution
$allResults = @()

# Extract permission identifiers
$permissionIdentifiers = Extract-PermissionIdentifiers -permissionsRefPath $PermissionsReferencePath

foreach ($version in $Versions) {
    Write-Host "Starting to process $version API files..."
    $versionResults = Process-ApiFiles -version $version -permissionIdentifiers $permissionIdentifiers
    $allResults += $versionResults
    Write-Host "Completed processing $version API files. Found $($versionResults.Count) mappings."
}

# Save as JSON
$allResults | ConvertTo-Json -Depth 4 | Out-File -FilePath $JsonOutputPath
Write-Host "Saved JSON output to $JsonOutputPath"