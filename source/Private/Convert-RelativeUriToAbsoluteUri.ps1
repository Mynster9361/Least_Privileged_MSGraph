function Convert-RelativeUriToAbsoluteUri {
  <#
.SYNOPSIS
    Converts a relative Microsoft Graph API URI to an absolute URI with normalized segments.

.DESCRIPTION
    This function takes a relative or partial Microsoft Graph API URI and converts it to a standardized
    absolute URI. It normalizes the URI by replacing dynamic segments like '/me' with '/users/{id}' and
    email addresses with '{id}' placeholders. This is useful for comparing API endpoints and mapping
    permissions to activities.

.PARAMETER Uri
    The relative or partial URI to convert. Can be a Graph API endpoint path like '/me/messages' or
    '/users/user@domain.com/mailFolders'.

.OUTPUTS
    PSCustomObject
    Returns an object with three properties:
    - Uri: The full absolute URI (e.g., 'https://graph.microsoft.com/v1.0/users/{id}/messages')
    - Path: The API path without the base URL (e.g., '/users/{id}/messages')
    - Version: The API version extracted from the URI ('v1.0', 'beta', or empty string)

.EXAMPLE
    Convert-RelativeUriToAbsoluteUri -Uri "/me/messages"
    
    Returns:
    Uri     : https://graph.microsoft.com/v1.0/users/{id}/messages
    Path    : /users/{id}/messages
    Version : v1.0

.EXAMPLE
    Convert-RelativeUriToAbsoluteUri -Uri "/users/user@contoso.com/mailFolders"
    
    Returns:
    Uri     : https://graph.microsoft.com/v1.0/users/{id}/mailFolders
    Path    : /users/{id}/mailFolders
    Version : v1.0

.NOTES
    This function normalizes URIs by:
    - Replacing '/me' segments with '/users/{id}'
    - Replacing email addresses with '{id}' placeholders
    - Unescaping URL-encoded characters
    - Removing leading and trailing slashes
#>
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