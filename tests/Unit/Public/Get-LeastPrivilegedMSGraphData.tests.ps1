BeforeAll {
  $script:moduleName = 'LeastPrivilegedMSGraph'

  # Remove any existing module
  Get-Module $script:moduleName -All | Remove-Module -Force -ErrorAction SilentlyContinue

  # Try to import the module using the same pattern as QA tests
  $moduleInfo = Get-Module -Name $script:moduleName -ListAvailable | Select-Object -First 1

  if ($moduleInfo) {
    Import-Module -Name $script:moduleName -Force -ErrorAction Stop
  }
  else {
    # Fallback: dot source the functions directly for testing
    $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "ConvertTo-LeastPrivilegedMSGraphObject.ps1" -ErrorAction SilentlyContinue
    $publicFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Public" -Filter "Get-LeastPrivilegedMSGraphData.ps1" -ErrorAction SilentlyContinue

    if ($privateFunction) {
      . $privateFunction.FullName 
    }
    if ($publicFunction) {
      . $publicFunction.FullName 
    }

    if (-not $privateFunction -or -not $publicFunction) {
      throw "Could not find required source files"
    }
  }
}
AfterAll {
  Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}
Describe 'Get-LeastPrivilegedMSGraphData' {
  It 'Should return a PSCustomObject with Name property' {
    $result = Get-LeastPrivilegedMSGraphData -Name 'Test'
    $result.Name | Should -Be 'Test'
  }
}
