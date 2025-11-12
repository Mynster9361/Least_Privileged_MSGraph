# Microsoft Graph Permissions Extractor

This tool extracts Microsoft Graph API permissions data from OpenAPI specifications and queries the Microsoft Graph permissions API to gather detailed permission information for each endpoint and HTTP method.

## Overview

The extractor processes two OpenAPI specification files:
- `openapi/v1.0/openapi.yaml` - Microsoft Graph v1.0 API
- `openapi/beta/openapi.yaml` - Microsoft Graph Beta API

For each endpoint and HTTP method combination found in the OpenAPI specs, it queries the Microsoft Graph permissions API at:
`https://devxapi-func-prod-eastus.azurewebsites.net/permissions`

## Output Format

The tool generates JSON files with the following structure:

```json
[
  {
    "Endpoint": "/servicePrincipals/{servicePrincipal-id}/remoteDesktopSecurityConfiguration",
    "Version": "v1.0",
    "Method": {
      "GET": [
        {
          "value": "Application-RemoteDesktopConfig.ReadWrite.All",
          "scopeType": "Application",
          "consentDisplayName": null,
          "consentDescription": null,
          "isAdmin": true,
          "isLeastPrivilege": false,
          "isHidden": false
        }
      ],
      "PATCH": [
        {
          "value": "Application-RemoteDesktopConfig.ReadWrite.All",
          "scopeType": "Application",
          "consentDisplayName": null,
          "consentDescription": null,
          "isAdmin": true,
          "isLeastPrivilege": true,
          "isHidden": false
        }
      ]
    }
  }
]
```

## Usage

### Test Mode (Recommended First)
```bash
# Test with 100 endpoints to validate functionality
node test-extractor.js
```

### Production Mode  
```bash
# Full extraction (all ~42,000 endpoints - takes ~4 hours)
node run-production.js
```

### Manual Configuration
```bash
# Custom limits and delays  
LIMIT_COUNT=100 API_DELAY=50 node permissions-extractor.js

# Sequential mode (recommended for reliability)
SEQUENTIAL_MODE=true node permissions-extractor.js
```

### Via GitHub Actions

1. Go to the Actions tab in your GitHub repository
2. Find the "Microsoft Graph Permissions Extractor" workflow
3. Click "Run workflow"
4. The workflow will generate artifacts containing the extracted permissions data

## Files

- **`permissions-extractor.js`** - Core extraction engine
- **`test-extractor.js`** - Test with 100 endpoints  
- **`run-production.js`** - Full production extraction
- **`README.md`** - Documentation

### Local Installation

1. Ensure Node.js 22+ is installed
2. Install dependencies:
   ```bash
   npm install js-yaml axios
   ```
3. Run the extractor:
   ```bash
   node tools/permissions-extractor.js
   ```

## Configuration

### Environment Variables

- `API_DELAY`: Delay between API calls in milliseconds (default: 100)

### Rate Limiting

The tool implements rate limiting to avoid overwhelming the Microsoft Graph permissions API:
- Configurable delay between requests
- Automatic retry with exponential backoff
- Maximum of 3 retry attempts per failed request

## Output Files

- `permissions-v1.0.json`: Permissions data for Microsoft Graph v1.0 API
- `permissions-beta.json`: Permissions data for Microsoft Graph Beta API
- `extraction-summary.md`: Summary report with statistics

## Features

- **Error Handling**: Robust error handling with retry logic
- **Progress Tracking**: Real-time progress logging with timestamps
- **Validation**: OpenAPI document validation before processing
- **Rate Limiting**: Configurable delays to respect API limits
- **Summary Reports**: Detailed statistics and coverage reports
- **Flexible Configuration**: Environment variable configuration

## Workflow Schedule

The GitHub Action is scheduled to run daily at 2 AM UTC to keep permissions data current.

## Troubleshooting

### Common Issues

1. **File Not Found**: Ensure OpenAPI files exist at expected paths
2. **API Rate Limiting**: Increase `API_DELAY` if experiencing frequent timeouts
3. **Network Issues**: The tool will automatically retry failed requests
4. **Invalid YAML**: Check OpenAPI file syntax if parsing fails

### Logs

The tool provides detailed logging with timestamps to help diagnose issues:
- File processing status
- API request progress
- Error messages with retry information
- Summary statistics

## Example Usage

### Query Structure

For each endpoint found in the OpenAPI specs, the tool makes requests like:

```
GET https://devxapi-func-prod-eastus.azurewebsites.net/permissions?requesturl=/users/{user-id}&method=GET&graphVersion=v1.0
```

### Sample Output Statistics

```
[2024-11-08T10:00:00.000Z] Summary for v1.0:
[2024-11-08T10:00:00.000Z]   - Total endpoints: 1250
[2024-11-08T10:00:00.000Z]   - Total methods: 3500
[2024-11-08T10:00:00.000Z]   - Total permissions: 15000
[2024-11-08T10:00:00.000Z]   - Endpoints with permissions: 1200 (96.00%)
```

## Contributing

When contributing to this tool:
1. Test with a small subset of endpoints first
2. Verify the output format matches the expected structure
3. Check that rate limiting is appropriate for the API
4. Update documentation for any configuration changes