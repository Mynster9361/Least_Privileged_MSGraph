#!/usr/bin/env node

/**
 * Microsoft Graph Permissions Extractor Test
 * Tests with 100 endpoints to validate functionality before production run
 */

const { spawn } = require('child_process');
const path = require('path');

console.log('🧪 Microsoft Graph Permissions Extractor - Test Mode');
console.log('Testing with 100 endpoints to validate functionality...');
console.log('');

// Optimized test settings matching production
const TEST_ENV = {
  API_DELAY: '50',            // Same as production
  CONCURRENT_REQUESTS: '1',   // Sequential only
  MAX_CONCURRENT_BATCHES: '1',
  SEQUENTIAL_MODE: 'true',    // Force sequential
  TEST_MODE: 'true',
  LIMIT_COUNT: '100',         // Reasonable test sample
  SKIP_COUNT: '0'
};

console.log('Test settings:');
Object.entries(TEST_ENV).forEach(([key, value]) => {
  console.log(`  ${key}: ${value}`);
});
console.log('');

function runTest() {
  return new Promise((resolve, reject) => {
    const scriptPath = path.join(__dirname, 'permissions-extractor.js');
    
    console.log('Starting test extraction...');
    const startTime = Date.now();
    
    const child = spawn('node', [scriptPath], {
      env: { ...process.env, ...TEST_ENV },
      stdio: 'inherit'
    });
    
    child.on('close', (code) => {
      const endTime = Date.now();
      const duration = ((endTime - startTime) / 1000).toFixed(2);
      
      if (code === 0) {
        console.log(`\n✅ Test extraction completed successfully!`);
        console.log(`⏱️  Test duration: ${duration} seconds`);
        resolve(code);
      } else {
        console.log(`\n❌ Test extraction failed with code ${code}`);
        console.log(`⏱️  Test duration: ${duration} seconds`);
        reject(new Error(`Process exited with code ${code}`));
      }
    });
    
    child.on('error', (error) => {
      console.error(`\n❌ Failed to start test: ${error.message}`);
      reject(error);
    });
  });
}

async function main() {
  try {
    await runTest();
    
    console.log('\n🎉 TEST SUCCESSFUL!');
    console.log('✅ Extractor functionality validated');
    console.log('🚀 Ready for production run');
    console.log('');
    console.log('To run full production extraction:');
    console.log('  node run-production.js');
    
  } catch (error) {
    console.error('\n💥 Test failed:', error.message);
    console.log('❌ Fix issues before running production extraction');
    process.exit(1);
  }
}

main();