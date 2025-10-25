param (
    [Parameter(Mandatory = $true)]
    [string]$DocsPath,
    [string]$JsonOutputPath = "graph_api_permissions_map.json",
    [string[]]$Versions = @("v1.0", "beta")
)
function Convert-PermissionsMarkdownToObject {
    param(
        [string]$MarkdownFilePath
    )
    
    # Check if file exists
    if (-not (Test-Path $MarkdownFilePath)) {
        Write-Error "File not found: $MarkdownFilePath"
        return $null
    }
    
    # Read the file content
    $content = Get-Content $MarkdownFilePath -Raw
    
    # Extract metadata from the front matter
    $metadata = @{}
    if ($content -match '(?s)^---\s*\n(.+?)\n---') {
        $frontMatter = $matches[1]
        $frontMatter -split '\n' | ForEach-Object {
            if ($_ -match '^(.+?):\s*"?(.+?)"?\s*$') {
                $metadata[$matches[1]] = $matches[2]
            }
        }
    }
    
    # Parse the markdown table
    $lines = Get-Content $MarkdownFilePath
    $permissions = @()
    $tableHeaders = @()
    $inTable = $false
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        
        # Find the header row (contains "Permission type")
        if ($line -like "*Permission type*" -and $line.StartsWith('|') -and $line.EndsWith('|')) {
            $tableHeaders = $line -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            $inTable = $true
            continue
        }
        
        # Skip the separator row (contains :--- patterns)
        if ($inTable -and $line -like "*:---*") {
            continue
        }
        
        # Process data rows
        if ($inTable -and $line.StartsWith('|') -and $line.EndsWith('|') -and $line -notlike "*:---*") {
            $cells = $line -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
            
            if ($cells.Count -eq $tableHeaders.Count) {
                $permissionObj = [PSCustomObject]@{
                    PermissionType             = $cells[0]
                    LeastPrivilegedPermissions = $cells[1]
                }
                
                $permissions += $permissionObj
            }
        }
        
        # Stop when we hit an empty line or non-table content
        if ($inTable -and ([string]::IsNullOrWhiteSpace($line) -or (-not $line.StartsWith('|')))) {
            break
        }
    }
    
    # Create the final object
    $result = [PSCustomObject]@{
        Metadata     = $metadata
        FilePath     = $MarkdownFilePath
        FileName     = Split-Path $MarkdownFilePath -Leaf
        Permissions  = $permissions
        TableHeaders = $tableHeaders
        ParsedDate   = Get-Date
    }
    
    return $result
}

function Convert-MultiplePermissionFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderPath,
        [string]$Pattern = "*permissions.md"
    )
    
    $files = Get-ChildItem -Path $FolderPath -Filter $Pattern -Recurse
    $allPermissions = @()
    
    foreach ($file in $files) {
        Write-Host "Processing: $($file.Name)" -ForegroundColor Green
        $result = Convert-PermissionsMarkdownToObject -MarkdownFilePath $file.FullName
        if ($result) {
            # Handle numbered permission files (e.g., -2-permissions.md, -3-permissions.md)
            #$apiReferencePath = $($result.FilePath -replace "\\includes\\permissions", "\api") -replace '-\d+-permissions\.md$', '.md' -replace '-permissions\.md$', '.md'
            $apiReferencePath = $result.FilePath -replace [regex]::Escape("includes/permissions"), "api" -replace '-\d*-permissions\.md$', '.md'
            $allPermissions += [PSCustomObject]@{
                fileName                = $result.FileName
                filePath                = $result.FilePath
                apiReferencePath        = $apiReferencePath
                delegatedPersonal_Least = $result.Permissions | Where-Object { $_.PermissionType -eq 'Delegated (personal Microsoft account)' } | Select-Object -ExpandProperty LeastPrivilegedPermissions
                delegatedWork_Least     = $result.Permissions | Where-Object { $_.PermissionType -eq 'Delegated (work or school account)' } | Select-Object -ExpandProperty LeastPrivilegedPermissions
                application_Least       = $result.Permissions | Where-Object { $_.PermissionType -eq 'Application' } | Select-Object -ExpandProperty LeastPrivilegedPermissions
            }
        }
    }
    
    return $allPermissions
}

$refApiPath = Join-Path -Path $DocsPath -ChildPath "api-reference"

[System.Collections.ArrayList]$allPermissions = @()

foreach ($version in $Versions) {
    $includePath = Join-Path -Path $refApiPath -ChildPath "$($version)\includes\permissions"
    if (-not (Test-Path $includePath)) {
        Write-Warning "Include path not found: $includePath"
        continue
    }
    Write-Host "Processing permissions in: $includePath" -ForegroundColor Yellow
    $allPermissions.addrange($(Convert-MultiplePermissionFiles -FolderPath $includePath))
}


foreach ($permissionSet in $allPermissions) {
        # Add debugging here
    Write-Host "Original permission file: $($permissionSet.fileName)" -ForegroundColor Gray
    Write-Host "Calculated API reference file: $($permissionSet.apiReferencePath)" -ForegroundColor Yellow
    
    # Let's see what files actually exist in the api directory
    $apiDir = Split-Path $permissionSet.apiReferencePath -Parent
    if (Test-Path $apiDir) {
        $actualApiFiles = Get-ChildItem -Path $apiDir -Filter "*.md" | Select-Object -First 5 -ExpandProperty Name
        Write-Host "Sample actual API files in directory:" -ForegroundColor Cyan
        $actualApiFiles | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        
        # Try to find a matching file by removing the -permissions suffix and looking for similar names
        $baseFileName = $permissionSet.fileName -replace '-permissions\.md$', '.md'
        $possibleMatches = Get-ChildItem -Path $apiDir -Filter "*$($baseFileName.Replace('-permissions', ''))*" | Select-Object -ExpandProperty FullName
        
        if ($possibleMatches) {
            Write-Host "Possible matches found:" -ForegroundColor Green
            $possibleMatches | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            
            # Use the first match
            $permissionSet.apiReferencePath = $possibleMatches[0]
            Write-Host "Using: $($permissionSet.apiReferencePath)" -ForegroundColor Green
        }
    } else {
        Write-Host "API directory doesn't exist: $apiDir" -ForegroundColor Red
    }
    
    Write-Host "---" -ForegroundColor DarkGray
    
    # Check if the API reference file exists
    if (-not (Test-Path $permissionSet.apiReferencePath)) {
        Write-Warning "API reference file not found: $($permissionSet.apiReferencePath). Skipping..."
        continue
    }
    Write-Host "Processing API reference file: $($permissionSet.apiReferencePath)" -ForegroundColor Cyan
    
    # Check if the API reference file exists
    if (-not (Test-Path $permissionSet.apiReferencePath)) {
        Write-Warning "API reference file not found: $($permissionSet.apiReferencePath). Skipping..."
        continue
    }
    
    $apiData = get-content $permissionSet.apiReferencePath -Raw
    $version = $permissionSet.apiReferencePath -match "v1.0" ? "v1.0" : "beta"

    # Use regex to find HTTP code blocks with various formats
    $httpBlockPattern = '```\s*(?i:http)\s*\n(.*?)\n```'
    $httpBlockMatch = [regex]::Match($apiData, $httpBlockPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    if ($httpBlockMatch.Success) {
        $httpBlock = $httpBlockMatch.Groups[1].Value
        $httpBlock.Split("`n") | ForEach-Object {
            # Simplified regex to capture complete URLs including those with spaces
            if ($_ -match '^(GET|POST|PUT|PATCH|DELETE)\s+(.+)$') {
                $method = $matches[1]
                $url = $matches[2].Trim()
                
                # Extract all parameters from URL
                $allParams = [regex]::Matches($url, '\{([^}]+)\}') | ForEach-Object { $_.Groups[1].Value }
                $params = if ($allParams.Count -gt 0) { $allParams -join ', ' } else { $null }
                if ($params) {
                    Write-Host "Parameters found in URL: $params"
                }
                
                Write-Host "Method: $method, URL: $url"
                Add-Member -InputObject $permissionSet -MemberType NoteProperty -Name "method" -Value $method -Force
                Add-Member -InputObject $permissionSet -MemberType NoteProperty -Name "path" -Value $url -Force
                Add-Member -InputObject $permissionSet -MemberType NoteProperty -Name "version" -Value $version -Force
                Add-Member -InputObject $permissionSet -MemberType NoteProperty -Name "parameters" -Value $params -Force
                Continue  # Take only the first HTTP request found
            }
        }
    }
    else {
        # Fallback 1: Look for any code block that contains HTTP methods (without language specifier)
        $fallbackPattern = '```[^\r\n]*\r?\n(.*?)\r?\n```'
        $fallbackMatches = [regex]::Matches($apiData, $fallbackPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        $foundHttpMethod = $false
        foreach ($match in $fallbackMatches) {
            $blockContent = $match.Groups[1].Value
            # Updated pattern to match relative URLs (with or without /), and absolute URLs (https://...)
            if ($blockContent -match '(GET|POST|PUT|PATCH|DELETE)\s+(/|https?://|\w)') {
                $foundHttpMethod = $true
                $blockContent.Split("`n") | ForEach-Object {
                    # Simplified regex to capture complete URLs including those with spaces
                    if ($_ -match '^(GET|POST|PUT|PATCH|DELETE)\s+(.+)$') {
                        $method = $matches[1]
                        $url = $matches[2].Trim()
                        
                        # Extract all parameters from URL
                        $allParams = [regex]::Matches($url, '\{([^}]+)\}') | ForEach-Object { $_.Groups[1].Value }
                        $params = if ($allParams.Count -gt 0) { $allParams -join ', ' } else { $null }
                        if ($params) {
                            Write-Host "Parameters found in URL: $params"
                        }
                        
                        Write-Host "Method: $method, URL: $url (found via fallback)"
                        Add-Member -InputObject $permissionSet -MemberType NoteProperty -Name "method" -Value $method -Force
                        Add-Member -InputObject $permissionSet -MemberType NoteProperty -Name "path" -Value $url -Force
                        Add-Member -InputObject $permissionSet -MemberType NoteProperty -Name "version" -Value $version -Force
                        Add-Member -InputObject $permissionSet -MemberType NoteProperty -Name "parameters" -Value $params -Force
                    }
                }
                Continue  # Found HTTP methods, stop looking through other code blocks
            }
        }
        
        # Fallback 2: Look for msgraph-interactive code blocks
        if (-not $foundHttpMethod) {
            $msgraphPattern = '```msgraph-interactive\s*\r?\n(.*?)\r?\n```'
            $msgraphMatches = [regex]::Matches($apiData, $msgraphPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
            
            foreach ($match in $msgraphMatches) {
                $blockContent = $match.Groups[1].Value
                if ($blockContent -match '(GET|POST|PUT|PATCH|DELETE)\s+(/|https?://|\w)') {
                    $foundHttpMethod = $true
                    $blockContent.Split("`n") | ForEach-Object {
                        if ($_ -match '^(GET|POST|PUT|PATCH|DELETE)\s+(.+)$') {
                            $method = $matches[1]
                            $url = $matches[2].Trim()
                            # Extract all parameters from URL
                            $allParams = [regex]::Matches($url, '\{([^}]+)\}') | ForEach-Object { $_.Groups[1].Value }
                            $params = if ($allParams.Count -gt 0) { $allParams -join ', ' } else { $null }
                            if ($params) {
                                Write-Host "Parameters found in URL: $params"
                            }
                            Write-Host "Method: $method, URL: $url (found via msgraph-interactive fallback)"
                            Add-Member -InputObject $permissionSet -MemberType NoteProperty -Name "method" -Value $method -Force
                            Add-Member -InputObject $permissionSet -MemberType NoteProperty -Name "path" -Value $url -Force
                            Add-Member -InputObject $permissionSet -MemberType NoteProperty -Name "version" -Value $version -Force
                            Add-Member -InputObject $permissionSet -MemberType NoteProperty -Name "parameters" -Value $params -Force

                        }
                    }
                    Continue  # Found HTTP methods, stop looking through other code blocks
                }
            }
        }
        
        if (-not $foundHttpMethod) {
            Write-Warning "Could not find HTTP block in $($permissionSet.apiReferencePath)"
        }
    }
}


$allPermissions | Select-Object path, version, method, parameters, application_Least, delegatedWork_Least, delegatedPersonal_Least | ConvertTo-Json | Out-File -FilePath ".\permissions-summary.json" -Encoding utf8