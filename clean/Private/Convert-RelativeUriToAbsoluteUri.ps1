function Convert-RelativeUriToAbsoluteUri {
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