Describe 'Get-LeastPrivilegedMSGraphData Integration' {
  It 'Should work in a pipeline' {
    $names = @('A', 'B')
    $results = $names | Get-LeastPrivilegedMSGraphData
    $results.Count | Should -Be 2
    $results[0].Name | Should -Be 'A'
    $results[1].Name | Should -Be 'B'
  }
}
