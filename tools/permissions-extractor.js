const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');
const axios = require('axios');

// Configuration
const PERMISSIONS_API_BASE = 'https://devxapi-func-prod-eastus.azurewebsites.net/permissions';
// Resolve paths relative to the project root (one level up from tools directory)
const projectRoot = path.resolve(__dirname, '..');
const OPENAPI_FILES = [
  { path: path.join(projectRoot, 'openapi/v1.0/openapi.yaml'), version: 'v1.0' },
  { path: path.join(projectRoot, 'openapi/beta/openapi.yaml'), version: 'beta' }
];

// Rate limiting - delay between API calls (in ms)
const API_DELAY = parseInt(process.env.API_DELAY || '10');
const MAX_RETRIES = 0; // No retries to speed up processing
const RETRY_DELAY = 500;

// Testing configuration
const TEST_MODE = process.env.TEST_MODE === 'true' || process.argv.includes('--test');
const SKIP_COUNT = parseInt(process.env.SKIP_COUNT || process.argv.find(arg => arg.startsWith('--skip='))?.split('=')[1] || '0');
const LIMIT_COUNT = parseInt(process.env.LIMIT_COUNT || process.argv.find(arg => arg.startsWith('--limit='))?.split('=')[1] || '0');

// Performance optimizations
const BATCH_SIZE = parseInt(process.env.BATCH_SIZE || '50'); // Process endpoints in batches
const PROGRESS_INTERVAL = 25; // Log progress every N requests
const CONCURRENT_REQUESTS = parseInt(process.env.CONCURRENT_REQUESTS || '1'); // Sequential by default for reliability
const MAX_CONCURRENT_BATCHES = parseInt(process.env.MAX_CONCURRENT_BATCHES || '1'); // No parallel batches by default
const ERROR_THRESHOLD = 0.2; // Stop if more than 20% of requests fail
const SEQUENTIAL_MODE = process.env.SEQUENTIAL_MODE !== 'false'; // Force sequential processing

/**
 * Delays execution for specified milliseconds
 */
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Logs with timestamp
 */
function log(message) {
  console.log(`[${new Date().toISOString()}] ${message}`);
}

/**
 * Extracts HTTP methods from OpenAPI path object
 */
function extractHttpMethods(pathObject) {
  const httpMethods = ['get', 'post', 'put', 'patch', 'delete', 'head', 'options'];
  const methods = [];
  
  for (const method of httpMethods) {
    if (pathObject[method] && typeof pathObject[method] === 'object') {
      methods.push(method.toUpperCase());
    }
  }
  
  return methods;
}

/**
 * Extracts endpoints and their HTTP methods from OpenAPI document
 */
function extractEndpointsFromOpenAPI(openApiDoc) {
  const endpoints = [];
  
  if (!openApiDoc.paths) {
    log('No paths found in OpenAPI document');
    return endpoints;
  }

  for (const [pathUrl, pathObject] of Object.entries(openApiDoc.paths)) {
    // Skip if path object is invalid
    if (!pathObject || typeof pathObject !== 'object') {
      continue;
    }

    // Skip paths that only have descriptions (no actual methods)
    if (Object.keys(pathObject).length === 1 && pathObject.description) {
      continue;
    }

    const methods = extractHttpMethods(pathObject);

    if (methods.length > 0) {
      endpoints.push({
        endpoint: pathUrl,
        methods: methods
      });
    }
  }

  // Apply test mode filtering
  if (TEST_MODE || SKIP_COUNT > 0 || LIMIT_COUNT > 0) {
    log(`Original endpoint count: ${endpoints.length}`);
    
    let filteredEndpoints = endpoints;
    
    // Skip endpoints if specified
    if (SKIP_COUNT > 0) {
      filteredEndpoints = filteredEndpoints.slice(SKIP_COUNT);
      log(`Skipped first ${SKIP_COUNT} endpoints`);
    }
    
    // Limit endpoints if specified
    if (LIMIT_COUNT > 0) {
      filteredEndpoints = filteredEndpoints.slice(0, LIMIT_COUNT);
      log(`Limited to first ${LIMIT_COUNT} endpoints after skipping`);
    }
    
    log(`Filtered endpoint count: ${filteredEndpoints.length}`);
    return filteredEndpoints;
  }

  return endpoints;
}

/**
 * Fetches permissions for a specific endpoint and method - ultra-conservative for reliability
 */
async function fetchPermissions(endpoint, method, version) {
  try {
    const url = `${PERMISSIONS_API_BASE}?requesturl=${encodeURIComponent(endpoint)}&method=${method}&graphVersion=${version}`;
    
    const response = await axios.get(url, {
      timeout: 15000, // Generous timeout
      headers: {
        'User-Agent': 'GitHub-Action-Permissions-Extractor/1.0',
        'Accept': 'application/json'
      },
      maxRedirects: 5,
      validateStatus: function (status) {
        return status >= 200 && status < 500; // Accept 2xx, 3xx, 4xx
      }
    });

    // Handle different response formats
    let permissions = response.data;
    if (Array.isArray(permissions)) {
      return { success: true, permissions, status: response.status };
    } else if (permissions && typeof permissions === 'object') {
      return { 
        success: true, 
        permissions: permissions.permissions || permissions.data || permissions.value || [], 
        status: response.status 
      };
    } else {
      return { success: true, permissions: [], status: response.status };
    }

  } catch (error) {
    // Return error information for tracking
    return { 
      success: false, 
      permissions: [], 
      error: error.message,
      status: error.response?.status || 0
    };
  }
}

/**
 * Processes endpoints sequentially for maximum reliability
 */
async function processSequentially(endpoints, version, result, totalMethods, startTime) {
  let completedRequests = 0;
  let errorCount = 0;
  let successCount = 0;
  
  for (const { endpoint, methods } of endpoints) {
    const endpointData = {
      Endpoint: endpoint,
      Version: version,
      Method: {}
    };

    // Process each method for this endpoint
    for (const method of methods) {
      completedRequests++;
      
      // Progress logging
      if (completedRequests % PROGRESS_INTERVAL === 0 || completedRequests === totalMethods) {
        const currentTime = Date.now();
        const elapsed = (currentTime - startTime) / 1000;
        const rate = completedRequests / elapsed;
        const remaining = totalMethods - completedRequests;
        const eta = remaining > 0 ? (remaining / rate) : 0;
        const errorRate = completedRequests > 0 ? (errorCount / completedRequests) : 0;
        
        log(`Progress: ${completedRequests}/${totalMethods} (${((completedRequests/totalMethods)*100).toFixed(1)}%) | Rate: ${rate.toFixed(1)}/s | Errors: ${errorCount}/${completedRequests} (${(errorRate * 100).toFixed(1)}%) | ETA: ${eta.toFixed(0)}s`);
      }
      
      // Fetch permissions for this method
      const result = await fetchPermissions(endpoint, method, version);
      endpointData.Method[method] = result.permissions;
      
      // Track errors
      if (result.success) {
        successCount++;
      } else {
        errorCount++;
        if (errorCount <= 5) {
          log(`Error ${errorCount}: ${method} ${endpoint} - ${result.error} (Status: ${result.status})`);
        }
      }
      
      // Check error rate and potentially abort
      const errorRate = completedRequests > 0 ? (errorCount / completedRequests) : 0;
      if (errorRate > ERROR_THRESHOLD && completedRequests > 20) {
        log(`CRITICAL: Error rate too high (${(errorRate * 100).toFixed(1)}%). Aborting to prevent wasting time.`);
        log(`Consider checking API connectivity or increasing delays.`);
        throw new Error(`High error rate: ${(errorRate * 100).toFixed(1)}%`);
      }
      
      // Rate limiting delay
      if (completedRequests < totalMethods) {
        await delay(Math.max(API_DELAY, 50)); // Minimum 50ms between requests
      }
    }

    result.push(endpointData);
  }
  
  // Final summary
  if (errorCount > 0) {
    log(`Sequential processing completed with ${errorCount} errors out of ${totalMethods} requests (${((errorCount / totalMethods) * 100).toFixed(2)}% error rate)`);
  }
}

/**
 * Processes endpoints in parallel (legacy mode)
 */
async function processInParallel(endpoints, version, result, totalMethods, startTime) {
  // Prepare all method-endpoint combinations
  const allMethodEndpoints = [];
  const endpointMap = new Map();
  
  endpoints.forEach(({ endpoint, methods }) => {
    methods.forEach(method => {
      allMethodEndpoints.push({ method, endpoint });
    });
    endpointMap.set(endpoint, { Endpoint: endpoint, Version: version, Method: {} });
  });
  
  // Process in parallel chunks
  const chunks = [];
  for (let i = 0; i < allMethodEndpoints.length; i += CONCURRENT_REQUESTS) {
    chunks.push(allMethodEndpoints.slice(i, i + CONCURRENT_REQUESTS));
  }
  
  let completedRequests = 0;
  let errorCount = 0;
  let successCount = 0;
  
  // Process chunks with controlled concurrency
  for (let i = 0; i < chunks.length; i += MAX_CONCURRENT_BATCHES) {
    const batchChunks = chunks.slice(i, i + MAX_CONCURRENT_BATCHES);
    
    const batchPromises = batchChunks.map(async (chunk) => {
      const results = await fetchPermissionsBatch(chunk, version);
      completedRequests += results.length;
      return results;
    });
    
    const batchResults = await Promise.all(batchPromises);
    
    // Update endpoint map
    const flatResults = batchResults.flat();
    flatResults.forEach(({ method, endpoint, permissions, success, error, status }) => {
      const endpointData = endpointMap.get(endpoint);
      if (endpointData) {
        endpointData.Method[method] = permissions;
      }
      
      if (success) {
        successCount++;
      } else {
        errorCount++;
        if (errorCount <= 5) {
          log(`Error ${errorCount}: ${method} ${endpoint} - ${error} (Status: ${status})`);
        }
      }
    });
    
    // Progress and error monitoring
    const errorRate = completedRequests > 0 ? (errorCount / completedRequests) : 0;
    
    if (completedRequests % PROGRESS_INTERVAL === 0 || i + MAX_CONCURRENT_BATCHES >= chunks.length) {
      const currentTime = Date.now();
      const elapsed = (currentTime - startTime) / 1000;
      const rate = completedRequests / elapsed;
      const remaining = totalMethods - completedRequests;
      const eta = remaining > 0 ? (remaining / rate) : 0;
      
      log(`Progress: ${completedRequests}/${totalMethods} (${((completedRequests/totalMethods)*100).toFixed(1)}%) | Rate: ${rate.toFixed(1)}/s | Errors: ${errorCount}/${completedRequests} (${(errorRate * 100).toFixed(1)}%) | ETA: ${eta.toFixed(0)}s`);
    }
    
    if (errorRate > ERROR_THRESHOLD && completedRequests > 50) {
      log(`CRITICAL: High error rate detected (${(errorRate * 100).toFixed(1)}%). Switching to sequential mode.`);
      // Switch to sequential processing for remaining items
      const remainingChunks = chunks.slice(i + MAX_CONCURRENT_BATCHES);
      const remainingMethods = remainingChunks.flat();
      
      for (const { method, endpoint } of remainingMethods) {
        const result = await fetchPermissions(endpoint, method, version);
        const endpointData = endpointMap.get(endpoint);
        if (endpointData) {
          endpointData.Method[method] = result.permissions;
        }
        await delay(Math.max(API_DELAY, 100));
      }
      break;
    }
    
    // Delay between batches
    if (i + MAX_CONCURRENT_BATCHES < chunks.length) {
      await delay(Math.max(API_DELAY, 50));
    }
  }
  
  // Convert map to array
  result.push(...Array.from(endpointMap.values()));
}

/**
 * Fetches permissions for multiple method-endpoint combinations in parallel with error tracking
 */
async function fetchPermissionsBatch(methodEndpoints, version) {
  const promises = methodEndpoints.map(({ method, endpoint }) => 
    fetchPermissions(endpoint, method, version)
      .then(result => ({ 
        method, 
        endpoint, 
        permissions: result.permissions, 
        success: result.success,
        error: result.error,
        status: result.status
      }))
  );
  
  // Use Promise.allSettled to handle partial failures gracefully
  const results = await Promise.allSettled(promises);
  
  return results.map((result, index) => {
    if (result.status === 'fulfilled') {
      return result.value;
    } else {
      const { method, endpoint } = methodEndpoints[index];
      return { 
        method, 
        endpoint, 
        permissions: [], 
        success: false, 
        error: 'Promise rejected',
        status: 0
      };
    }
  });
}

/**
 * Validates OpenAPI document structure
 */
function validateOpenApiDoc(doc, filePath) {
  if (!doc) {
    throw new Error(`Invalid or empty OpenAPI document: ${filePath}`);
  }
  
  if (!doc.openapi && !doc.swagger) {
    throw new Error(`Not a valid OpenAPI document: ${filePath}`);
  }
  
  if (!doc.paths || typeof doc.paths !== 'object') {
    throw new Error(`No valid paths found in OpenAPI document: ${filePath}`);
  }
  
  return true;
}

/**
 * Processes a single OpenAPI file
 */
async function processOpenAPIFile(filePath, version) {
  log(`Processing ${filePath} (${version})`);
  
  try {
    // Check if file exists
    if (!fs.existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }

    // Read and parse the OpenAPI YAML file
    const fileContent = fs.readFileSync(filePath, 'utf8');
    const openApiDoc = yaml.load(fileContent);
    
    // Validate document
    validateOpenApiDoc(openApiDoc, filePath);
    
    // Extract endpoints and methods
    const endpoints = extractEndpointsFromOpenAPI(openApiDoc);
    log(`Found ${endpoints.length} valid endpoints in ${version}`);

    if (endpoints.length === 0) {
      log(`Warning: No endpoints found in ${version}`);
      return [];
    }

    const result = [];
    const totalMethods = endpoints.reduce((total, ep) => total + ep.methods.length, 0);
    
    // Show time estimate (updated for parallel processing)
    const estimate = estimateProcessingTime(totalMethods, API_DELAY / CONCURRENT_REQUESTS);
    log(`Processing ${totalMethods} endpoint-method combinations`);
    log(`Estimated completion time with parallel processing: ${estimate.timeString}`);

    const startTime = Date.now();
    
    // Choose processing mode based on settings
    if (SEQUENTIAL_MODE || CONCURRENT_REQUESTS <= 1) {
      log('Using sequential processing mode for maximum reliability');
      await processSequentially(endpoints, version, result, totalMethods, startTime);
    } else {
      log(`Using parallel processing mode with ${CONCURRENT_REQUESTS} concurrent requests`);
      await processInParallel(endpoints, version, result, totalMethods, startTime);
    }

    return result;
  } catch (error) {
    log(`Error processing ${filePath}: ${error.message}`);
    throw error;
  }
}

/**
 * Saves results to JSON file with proper formatting
 */
function saveResults(data, filename) {
  try {
    const jsonString = JSON.stringify(data, null, 2);
    fs.writeFileSync(filename, jsonString);
    log(`Results saved to ${filename}`);
    return true;
  } catch (error) {
    log(`Error saving results to ${filename}: ${error.message}`);
    return false;
  }
}

/**
 * Generates summary statistics
 */
function generateSummary(data, version) {
  const totalEndpoints = data.length;
  const totalMethods = data.reduce((total, endpoint) => {
    return total + Object.keys(endpoint.Method).length;
  }, 0);
  
  const totalPermissions = data.reduce((total, endpoint) => {
    return total + Object.values(endpoint.Method).reduce((methodTotal, permissions) => {
      return methodTotal + (Array.isArray(permissions) ? permissions.length : 0);
    }, 0);
  }, 0);
  
  const endpointsWithPermissions = data.filter(endpoint => {
    return Object.values(endpoint.Method).some(permissions => 
      Array.isArray(permissions) && permissions.length > 0
    );
  }).length;

  return {
    version,
    totalEndpoints,
    totalMethods,
    totalPermissions,
    endpointsWithPermissions,
    coveragePercent: totalEndpoints > 0 ? ((endpointsWithPermissions / totalEndpoints) * 100).toFixed(2) : 0
  };
}

/**
 * Estimates total processing time
 */
function estimateProcessingTime(totalMethods, apiDelay) {
  // Base time per request (observed ~1.5s per request including network latency)
  const baseTimePerRequest = 1.5;
  const delayTimePerRequest = apiDelay / 1000;
  const totalTimePerRequest = baseTimePerRequest + delayTimePerRequest;
  const totalTimeSeconds = totalMethods * totalTimePerRequest;
  
  const hours = Math.floor(totalTimeSeconds / 3600);
  const minutes = Math.floor((totalTimeSeconds % 3600) / 60);
  const seconds = Math.floor(totalTimeSeconds % 60);
  
  let timeString = '';
  if (hours > 0) timeString += `${hours}h `;
  if (minutes > 0) timeString += `${minutes}m `;
  timeString += `${seconds}s`;
  
  return { totalTimeSeconds, timeString };
}

/**
 * Main function
 */
async function main() {
  log('Starting Microsoft Graph permissions extraction...');
  log(`Performance settings:`);
  log(`  - API delay: ${API_DELAY}ms`);
  log(`  - Concurrent requests: ${CONCURRENT_REQUESTS}`);
  log(`  - Concurrent batches: ${MAX_CONCURRENT_BATCHES}`);
  log(`  - Batch size: ${BATCH_SIZE} endpoints`);
  
  if (TEST_MODE || SKIP_COUNT > 0 || LIMIT_COUNT > 0) {
    log('=== TEST MODE ENABLED ===');
    if (SKIP_COUNT > 0) log(`Skipping first ${SKIP_COUNT} endpoints`);
    if (LIMIT_COUNT > 0) log(`Limiting to ${LIMIT_COUNT} endpoints`);
  }

  const results = [];

  for (const { path: filePath, version } of OPENAPI_FILES) {
    try {
      const fullPath = path.resolve(filePath);
      
      // Process the OpenAPI file
      const permissionsData = await processOpenAPIFile(fullPath, version);
      
      if (permissionsData.length === 0) {
        log(`Warning: No data extracted for ${version}`);
        continue;
      }
      
      // Save results to JSON file
      const outputFileName = `permissions-${version}.json`;
      const saved = saveResults(permissionsData, outputFileName);
      
      if (saved) {
        // Generate and log summary
        const summary = generateSummary(permissionsData, version);
        log(`Summary for ${version}:`);
        log(`  - Total endpoints: ${summary.totalEndpoints}`);
        log(`  - Total methods: ${summary.totalMethods}`);
        log(`  - Total permissions: ${summary.totalPermissions}`);
        log(`  - Endpoints with permissions: ${summary.endpointsWithPermissions} (${summary.coveragePercent}%)`);
        
        results.push(summary);
      }
      
    } catch (error) {
      log(`Error processing ${version}: ${error.message}`);
      // Continue with other versions even if one fails
    }
  }

  // Final summary
  if (results.length > 0) {
    log('\n=== EXTRACTION COMPLETE ===');
    results.forEach(summary => {
      log(`${summary.version}: ${summary.totalEndpoints} endpoints, ${summary.totalMethods} methods, ${summary.coveragePercent}% coverage`);
    });
  } else {
    log('No data was successfully extracted');
    process.exit(1);
  }
}

// Handle uncaught errors
process.on('unhandledRejection', (reason, promise) => {
  log(`Unhandled Rejection at: ${promise}, reason: ${reason}`);
  process.exit(1);
});

process.on('uncaughtException', (error) => {
  log(`Uncaught Exception: ${error.message}`);
  process.exit(1);
});

// Run the main function
main().catch(error => {
  log(`Fatal error: ${error.message}`);
  process.exit(1);
});