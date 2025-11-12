function ConvertTo-TokenizeIds {
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$UriString
  )
  Write-Debug "Tokenizing URI: $UriString"
  $Uri = [System.Uri]::new($UriString)

  $TokenizedUri = $Uri.GetComponents([System.UriComponents]::SchemeAndServer, [System.UriFormat]::SafeUnescaped)
  write-Debug "Base URI: $TokenizedUri"
  $LastSegmentIndex = $Uri.Segments.length - 1
  write-Debug "Last Segment Index: $LastSegmentIndex"
  $LastSegment = $Uri.Segments[$LastSegmentIndex]
  write-Debug "Last Segment: $LastSegment"
  $UnescapedUri = $Uri.ToString()
  write-Debug "Unescaped URI: $UnescapedUri"
  for ($i = 0 ; $i -lt $Uri.Segments.length; $i++) {
    write-Debug "Processing Segment [$i]: $($Uri.Segments[$i])"
    # Segment contains an integer/id and is not API version.
    if ($Uri.Segments[$i] -match "[^v1.0|beta]\d") {
      write-Debug "Segment [$i] matches ID pattern."
      #For Uris whose last segments match the regex '(.*?)', all characters from the first '(' are substituted with '.*'
      if ($i -eq $LastSegmentIndex) {
        write-Debug "Segment [$i] is the last segment."
        if ($UnescapedUri -match '(.*?)') {
          write-Debug "Last segment matches pattern '(.*?)'."
          try {
            $UpdatedLastSegment = $LastSegment.Substring(0, $LastSegment.IndexOf("("))
            $TokenizedUri += $UpdatedLastSegment + "/{id}"
            write-Debug "Updated Last Segment: $UpdatedLastSegment.*"
          }
          catch {
            $TokenizedUri += "{id}/"
            write-Debug "Error processing last segment with '(.*?)' pattern. Substituted with {id}/"
          }
        }
      }
      else {
        write-Debug "Substituting Segment [$i] with {id}/"
        # Substitute integers/ids with {id} tokens, e.g, /users/289ee2a5-9450-4837-aa87-6bd8d8e72891 -> users/{id}.
        $TokenizedUri += "{id}/"
      }
    }
    else {
      write-Debug "Segment [$i] does not match ID pattern. Keeping original segment."
      $TokenizedUri += $Uri.Segments[$i]
    }
  }
  write-Debug "Final Tokenized URI: $TokenizedUri"
  return $TokenizedUri.TrimEnd("/")
}