function Convert-RelativeUriToAbsoluteUri {
  <#
.SYNOPSIS
    Internal function to convert relative Graph URIs to absolute URIs with normalized segments.

.DESCRIPTION
    This private function converts relative or partial Microsoft Graph API URIs to standardized
    absolute URIs. Used internally by Get-AppActivityFromLog and other functions for URI normalization.

    The function normalizes URIs by:
    - Replacing '/me' segments with '/users/{id}'
    - Replacing email addresses (containing '@') with '{id}'
    - Unescaping URL-encoded characters
    - Adding base URL if not present
    - Extracting API version (v1.0 or beta)

    This enables consistent URI patterns for permission mapping and activity aggregation.

.PARAMETER Uri
    The relative or partial URI to convert and normalize.
    Example: '/me/messages' or 'https://graph.microsoft.com/v1.0/users/user@domain.com/calendar'

.OUTPUTS
    PSCustomObject
    Object with three properties:
    - Uri: Full absolute URI with normalized segments
    - Path: API path without base URL and version
    - Version: 'v1.0', 'beta', or empty string

.EXAMPLE
    # Used internally by Get-AppActivityFromLog
    $processedUri = Convert-RelativeUriToAbsoluteUri -Uri $entry.Uri

.EXAMPLE
    Convert-RelativeUriToAbsoluteUri -Uri "https://graph.microsoft.com/v1.0/me/messages"
    # Returns: Uri='https://graph.microsoft.com/v1.0/users/{id}/messages', Path='/users/{id}/messages', Version='v1.0'

.EXAMPLE
    Convert-RelativeUriToAbsoluteUri -Uri "https://graph.microsoft.com/v1.0/users/john@contoso.com/mailFolders"
    # Returns: Uri='https://graph.microsoft.com/v1.0/users/{id}/mailFolders', Path='/users/{id}/mailFolders', Version='v1.0'

.NOTES
    This is a private module function not exported to users.

    Normalization Rules:
    - '/me' segments -> '/users/{id}'
    - Email addresses (with '@') -> '{id}'
    - URL-encoded characters unescaped
    - Leading/trailing slashes removed
    - Base URL added if missing (https://graph.microsoft.com)
    - Default version 'v1.0' if not specified

    Uses Write-Debug for detailed processing steps. Run with -Debug to see normalization details.

.LINK
    Get-AppActivityFromLog

.LINK
    ConvertTo-TokenizeId
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
    Version = if ($ProcessedUri -like "*https://graph.microsoft.com/v1.0*") {
      "v1.0"
    }
    elseif ($ProcessedUri -like "*https://graph.microsoft.com/beta*") {
      "beta"
    }
    else {
      ""
    }
  }

  return $returnObject
}
