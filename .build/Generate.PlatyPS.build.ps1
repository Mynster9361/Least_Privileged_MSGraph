param
(
  # Project path
  [Parameter()]
  [System.String]
  $ProjectPath = (property ProjectPath $BuildRoot),

  [Parameter()]
  [System.String]
  $OutputDirectory = (property OutputDirectory (Join-Path $BuildRoot 'output')),

  [Parameter()]
  [System.String]
  $BuiltModuleSubdirectory = (property BuiltModuleSubdirectory 'module'),

  [Parameter()]
  [System.String]
  $ModuleName = (property ModuleName 'LeastPrivilegedMSGraph'),

  [Parameter()]
  [System.String]
  $DocsOutputPath = (property DocsOutputPath 'docs')
)

# Synopsis: Generate markdown help files using PlatyPS
task Generate_Conceptual_Help {
  if (-not (Get-Module -Name 'PlatyPS' -ListAvailable)) {
    Write-Build Red 'PlatyPS module is not available. Skipping documentation generation.'
    return
  }

  Import-Module -Name 'PlatyPS' -Force

  $docsPath = Join-Path -Path $OutputDirectory -ChildPath $DocsOutputPath

  if (-not (Test-Path -Path $docsPath)) {
    $null = New-Item -Path $docsPath -ItemType Directory -Force
  }

  # Build the correct path to the module manifest
  $builtModulePath = Join-Path -Path $OutputDirectory -ChildPath $BuiltModuleSubdirectory
  $moduleVersionPath = Join-Path -Path $builtModulePath -ChildPath $ModuleName

  Write-Build Green "Checking for built module at: $moduleVersionPath"

  # Check if the module path exists
  if (-not (Test-Path -Path $moduleVersionPath)) {
    Write-Build Red "Module path does not exist: $moduleVersionPath"
    Write-Build Yellow "The module must be built before generating documentation."
    Write-Build Yellow "Try running: ./build.ps1 -Tasks build"
    return
  }

  # Find the versioned folder (e.g., 0.1.0-preview1)
  $versionFolders = Get-ChildItem -Path $moduleVersionPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending

  if ($versionFolders.Count -gt 0) {
    $moduleManifestPath = Join-Path -Path $versionFolders[0].FullName -ChildPath "$ModuleName.psd1"
    Write-Build Green "Found versioned module: $($versionFolders[0].Name)"
  }
  else {
    # Fallback: try direct path
    $moduleManifestPath = Join-Path -Path $moduleVersionPath -ChildPath "$ModuleName.psd1"
  }

  Write-Build Green "Looking for module manifest at: $moduleManifestPath"

  if (Test-Path -Path $moduleManifestPath) {
    Write-Build Green "Importing module from: $moduleManifestPath"
    Import-Module -Name $moduleManifestPath -Force -Global

    # Generate markdown help for all commands
    try {
      Write-Build Green "Generating markdown help files in: $docsPath"
      $null = New-MarkdownHelp -Module $ModuleName -OutputFolder $docsPath -Force
      Write-Build Green "Documentation generated successfully"

      # List generated files
      $generatedFiles = Get-ChildItem -Path $docsPath -Filter "*.md"
      Write-Build Green "Generated $($generatedFiles.Count) documentation files:"
      $generatedFiles | ForEach-Object { Write-Build Green "  - $($_.Name)" }
    }
    catch {
      Write-Build Red "Failed to generate documentation: $_"
      throw
    }
    finally {
      Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue
    }
  }
  else {
    Write-Build Red "Module manifest not found at: $moduleManifestPath"
    Write-Build Yellow "Available .psd1 files in output directory:"
    if (Test-Path $OutputDirectory) {
      Get-ChildItem -Path $OutputDirectory -Recurse -Filter "*.psd1" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Build Yellow "  $($_.FullName)"
      }
    }
  }
}

# Synopsis: Generate external help file from markdown
task Generate_External_Help_File_For_Public_Commands {
  if (-not (Get-Module -Name 'PlatyPS' -ListAvailable)) {
    Write-Build Red 'PlatyPS module is not available. Skipping external help generation.'
    return
  }

  Import-Module -Name 'PlatyPS' -Force

  $docsPath = Join-Path -Path $OutputDirectory -ChildPath $DocsOutputPath

  # Fix the Join-Path issue - build the path step by step
  $moduleSubPath = Join-Path -Path $OutputDirectory -ChildPath $BuiltModuleSubdirectory
  $moduleNamePath = Join-Path -Path $moduleSubPath -ChildPath $ModuleName

  # Check if module path exists
  if (-not (Test-Path -Path $moduleNamePath)) {
    Write-Build Yellow "Module path does not exist: $moduleNamePath"
    Write-Build Yellow "Skipping external help generation."
    return
  }

  # Find the versioned folder
  $versionFolders = Get-ChildItem -Path $moduleNamePath -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending

  if ($versionFolders.Count -gt 0) {
    $helpOutputPath = Join-Path -Path $versionFolders[0].FullName -ChildPath 'en-US'
  }
  else {
    $helpOutputPath = Join-Path -Path $moduleNamePath -ChildPath 'en-US'
  }

  if (-not (Test-Path -Path $helpOutputPath)) {
    $null = New-Item -Path $helpOutputPath -ItemType Directory -Force
  }

  Write-Build Green "External help output path: $helpOutputPath"

  if (Test-Path -Path $docsPath) {
    try {
      Write-Build Green "Generating external help file from markdown in: $docsPath"
      $null = New-ExternalHelp -Path $docsPath -OutputPath $helpOutputPath -Force
      Write-Build Green "External help file generated successfully"

      # List generated help files
      $helpFiles = Get-ChildItem -Path $helpOutputPath -Filter "*.xml"
      Write-Build Green "Generated external help files:"
      $helpFiles | ForEach-Object { Write-Build Green "  - $($_.Name)" }
    }
    catch {
      Write-Build Red "Failed to generate external help: $_"
      throw
    }
  }
  else {
    Write-Build Yellow "Documentation path not found: $docsPath"
    Write-Build Yellow "Run Generate_Conceptual_Help first to create markdown files."
  }
}
