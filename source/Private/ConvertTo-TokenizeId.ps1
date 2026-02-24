function ConvertTo-TokenizeId {
  <#
.SYNOPSIS
    Internal function to tokenize ID values in URIs by replacing them with {id} placeholders.

.DESCRIPTION
    This private function processes URIs and replaces numeric ID segments with {id} tokens to create
    standardized URI patterns. Used internally by Get-AppActivityFromLog for permission mapping.

    The function:
    - Preserves API version segments (v1.0, beta)
    - Replaces GUID identifiers with {id}
    - Replaces numeric IDs with {id}
    - Handles OData function parameters in the last segment
    - Maintains scheme, host, and query parameters

    Special handling: If the last segment contains '(' (OData functions like messages(filter='...')),
    everything from '(' onwards is replaced with '/{id}'.

.PARAMETER UriString
    Complete URI string to tokenize. Must be valid URI with scheme and host.
    Example: 'https://graph.microsoft.com/v1.0/users/guid-here/messages'

.OUTPUTS
    String
    Tokenized URI with ID segments replaced by {id} placeholders.
    Example: 'https://graph.microsoft.com/v1.0/users/{id}/messages'

.EXAMPLE
    # Used internally by Get-AppActivityFromLog
    $tokenizedUri = ConvertTo-TokenizeId -UriString $processedUriObject.Uri

.EXAMPLE
    ConvertTo-TokenizeId -UriString "https://graph.microsoft.com/v1.0/users/guid/messages"
    # Returns: https://graph.microsoft.com/v1.0/users/{id}/messages

.NOTES
    This is a private module function not exported to users.

    Tokenization Rules:
    - Segments with digits (except 'v1.0' or 'beta') -> {id}
    - Last segment with '(.*?)' pattern -> special handling
    - API version segments always preserved
    - Trailing slashes removed

    Uses Write-PSFMessage -Level Debug -Message extensively. Run with -Debug to see segment processing details.

.LINK
    Get-AppActivityFromLog

.LINK
    Convert-RelativeUriToAbsoluteUri
#>
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$UriString
  )
  Write-PSFMessage -Level Debug -Message  "Tokenizing URI: $UriString"
  $Uri = [System.Uri]::new($UriString)

  $TokenizedUri = $Uri.GetComponents([System.UriComponents]::SchemeAndServer, [System.UriFormat]::SafeUnescaped)
  $LastSegmentIndex = $Uri.Segments.length - 1
  $LastSegment = $Uri.Segments[$LastSegmentIndex]
  Write-PSFMessage -Level Debug -Message  "Last Segment: $LastSegment"
  $UnescapedUri = $Uri.ToString()
  for ($i = 0 ; $i -lt $Uri.Segments.length; $i++) {
    Write-PSFMessage -Level Debug -Message  "Processing Segment [$i]: $($Uri.Segments[$i])"

    $segment = $Uri.Segments[$i].TrimEnd('/')

    # Check if this is a guest user identifier (contains underscore, not a GUID, not @ symbol)
    # GUID pattern: 8-4-4-4-12 format with hyphens
    $isGuestUser = $segment -match '_' -and
    $segment -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' -and
    $segment -notmatch '@'

    # Segment contains an integer/id or is a guest user, and is not API version
    if (($Uri.Segments[$i] -match "[^v1.0|beta]\d") -or $isGuestUser) {
      Write-PSFMessage -Level Debug -Message  "Segment [$i] matches ID pattern or guest user."
      #For Uris whose last segments match the regex '(.*?)', all characters from the first '(' are substituted with '.*'
      if ($i -eq $LastSegmentIndex) {
        Write-PSFMessage -Level Debug -Message  "Segment [$i] is the last segment."
        if ($UnescapedUri -match '(.*?)') {
          Write-PSFMessage -Level Debug -Message  "Last segment matches pattern '(.*?)'."
          try {
            $UpdatedLastSegment = $LastSegment.Substring(0, $LastSegment.IndexOf("("))
            $TokenizedUri += $UpdatedLastSegment + "/{id}"
            Write-PSFMessage -Level Debug -Message  "Updated Last Segment: $UpdatedLastSegment.*"
          }
          catch {
            $TokenizedUri += "{id}/"
            Write-PSFMessage -Level Debug -Message  "Error processing last segment with '(.*?)' pattern. Substituted with {id}/"
          }
        }
      }
      else {
        Write-PSFMessage -Level Debug -Message  "Substituting Segment [$i] with {id}/"
        # Substitute integers/ids/guest users with {id} tokens
        $TokenizedUri += "{id}/"
      }
    }
    else {
      Write-PSFMessage -Level Debug -Message  "Segment [$i] does not match ID pattern. Keeping original segment."
      # Handle delta() function - strip the empty parentheses
      if ($Uri.Segments[$i] -match 'delta\(\)') {
        $cleanedSegment = $Uri.Segments[$i] -replace 'delta\(\)', 'delta'
        Write-PSFMessage -Level Debug -Message  "Cleaned delta() to delta: $cleanedSegment"
        $TokenizedUri += $cleanedSegment
      }
      else {
        $TokenizedUri += $Uri.Segments[$i]
      }
    }
  }
  Write-PSFMessage -Level Debug -Message  "Final Tokenized URI: $TokenizedUri"
  return $TokenizedUri.TrimEnd("/")
}
