function ConvertTo-TokenizeId {
  <#
.SYNOPSIS
    Tokenizes ID values in a URI by replacing them with {id} placeholders.

.DESCRIPTION
    This function processes a URI and replaces numeric ID segments with {id} tokens to create a
    standardized URI pattern. This is useful for grouping similar API calls that differ only by
    the resource IDs, enabling pattern matching for permission analysis and activity mapping.

    The function preserves API version segments (v1.0/beta) and only tokenizes segments that
    contain numeric IDs. Special handling is applied to the last segment if it contains patterns
    like '(.*?)' commonly used in OData filters.

.PARAMETER UriString
    The complete URI string to tokenize. Must be a valid URI with scheme and host.
    Example: 'https://graph.microsoft.com/v1.0/users/289ee2a5-9450-4837-aa87-6bd8d8e72891/messages'

.OUTPUTS
    String
    Returns the tokenized URI with ID segments replaced by {id} placeholders.
    Example: 'https://graph.microsoft.com/v1.0/users/{id}/messages'

.EXAMPLE
    ConvertTo-TokenizeId -UriString "https://graph.microsoft.com/v1.0/users/289ee2a5-9450-4837-aa87-6bd8d8e72891/messages"

    Returns:
    https://graph.microsoft.com/v1.0/users/{id}/messages

.EXAMPLE
    ConvertTo-TokenizeId -UriString "https://graph.microsoft.com/v1.0/groups/12345/members"

    Returns:
    https://graph.microsoft.com/v1.0/groups/{id}/members

.EXAMPLE
    ConvertTo-TokenizeId -UriString "https://graph.microsoft.com/v1.0/users/user@domain.com/messages(filter='isRead eq false')"

    Returns:
    https://graph.microsoft.com/v1.0/users/{id}/messages/{id}

    Note: The last segment with '(.*?)' pattern is replaced with {id}

.NOTES
    Tokenization rules:
    - Segments containing digits (except 'v1.0' or 'beta') are replaced with {id}
    - The last segment with '(.*?)' pattern gets special handling
    - API version segments (v1.0/beta) are preserved
    - Trailing slashes are removed from the final result

    This function uses Write-Debug extensively, so run with -Debug to see detailed processing steps.
#>
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$UriString
  )
  Write-Debug "Tokenizing URI: $UriString"
  $Uri = [System.Uri]::new($UriString)

  $TokenizedUri = $Uri.GetComponents([System.UriComponents]::SchemeAndServer, [System.UriFormat]::SafeUnescaped)
  Write-Debug "Base URI: $TokenizedUri"
  $LastSegmentIndex = $Uri.Segments.length - 1
  Write-Debug "Last Segment Index: $LastSegmentIndex"
  $LastSegment = $Uri.Segments[$LastSegmentIndex]
  Write-Debug "Last Segment: $LastSegment"
  $UnescapedUri = $Uri.ToString()
  Write-Debug "Unescaped URI: $UnescapedUri"
  for ($i = 0 ; $i -lt $Uri.Segments.length; $i++) {
    Write-Debug "Processing Segment [$i]: $($Uri.Segments[$i])"
    # Segment contains an integer/id and is not API version.
    if ($Uri.Segments[$i] -match "[^v1.0|beta]\d") {
      Write-Debug "Segment [$i] matches ID pattern."
      #For Uris whose last segments match the regex '(.*?)', all characters from the first '(' are substituted with '.*'
      if ($i -eq $LastSegmentIndex) {
        Write-Debug "Segment [$i] is the last segment."
        if ($UnescapedUri -match '(.*?)') {
          Write-Debug "Last segment matches pattern '(.*?)'."
          try {
            $UpdatedLastSegment = $LastSegment.Substring(0, $LastSegment.IndexOf("("))
            $TokenizedUri += $UpdatedLastSegment + "/{id}"
            Write-Debug "Updated Last Segment: $UpdatedLastSegment.*"
          }
          catch {
            $TokenizedUri += "{id}/"
            Write-Debug "Error processing last segment with '(.*?)' pattern. Substituted with {id}/"
          }
        }
      }
      else {
        Write-Debug "Substituting Segment [$i] with {id}/"
        # Substitute integers/ids with {id} tokens, e.g, /users/289ee2a5-9450-4837-aa87-6bd8d8e72891 -> users/{id}.
        $TokenizedUri += "{id}/"
      }
    }
    else {
      Write-Debug "Segment [$i] does not match ID pattern. Keeping original segment."
      $TokenizedUri += $Uri.Segments[$i]
    }
  }
  Write-Debug "Final Tokenized URI: $TokenizedUri"
  return $TokenizedUri.TrimEnd("/")
}
