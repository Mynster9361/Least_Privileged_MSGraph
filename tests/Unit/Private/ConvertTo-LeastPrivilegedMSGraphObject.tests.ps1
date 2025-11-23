BeforeAll {
  $script:moduleName = 'LeastPrivilegedMSGraph'

  # Remove any existing module
  Get-Module $script:moduleName -All | Remove-Module -Force -ErrorAction SilentlyContinue

  # Find and dot source the private function for testing
  $privateFunction = Get-ChildItem -Path "$PSScriptRoot/../../../source/Private" -Filter "ConvertTo-LeastPrivilegedMSGraphObject.ps1" -ErrorAction SilentlyContinue

  if ($privateFunction) {
    . $privateFunction.FullName
  }
  else {
    throw "Could not find ConvertTo-LeastPrivilegedMSGraphObject.ps1 in source/Private directory"
  }
}
AfterAll {
  Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}
Describe 'ConvertTo-LeastPrivilegedMSGraphObject' {
  It 'Should create a PSCustomObject with Name property' {
    $obj = ConvertTo-LeastPrivilegedMSGraphObject -Name 'PrivateTest'
    $obj.Name | Should -Be 'PrivateTest'
  }
}
