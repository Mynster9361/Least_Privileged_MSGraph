#!/usr/bin/env node
/**
 #TODO: Change diffrent id placement values to always be {id}
 * Ultra-fast production runner for Microsoft Graph Permissions Extractor
 * Optimized for GitHub Actions with aggressive parallel processing
 */

const { spawn } = require('child_process');
const path = require('path');

console.log('🚀 Microsoft Graph Permissions Extractor - Production Mode');
console.log('🛡️ Sequential processing for 100% reliability');
console.log('');

// Optimized production configuration for GitHub Actions
const PRODUCTION_ENV = {
  API_DELAY: '50',            // Faster delay (tested reliable at 200ms)
  CONCURRENT_REQUESTS: '1',   // Sequential processing (proven reliable)
  MAX_CONCURRENT_BATCHES: '1', // No parallel batching  
  BATCH_SIZE: '50',           // Standard batch size
  SEQUENTIAL_MODE: 'true'     // Force sequential mode
};

console.log('Production settings:');
Object.entries(PRODUCTION_ENV).forEach(([key, value]) => {
  console.log(`  ${key}: ${value}`);
});
console.log('');

function runExtractor(env) {
  return new Promise((resolve, reject) => {
    const extractorPath = path.join(__dirname, 'permissions-extractor.js');
    
    console.log('Starting full extraction...');
    const startTime = Date.now();
    
    const child = spawn('node', [extractorPath], {
      stdio: 'inherit',
      env: { ...process.env, ...env }
    });
    
    child.on('close', (code) => {
      const endTime = Date.now();
      const duration = ((endTime - startTime) / 1000).toFixed(2);
      
      console.log('');
      if (code === 0) {
        console.log('🎉 PRODUCTION EXTRACTION COMPLETED SUCCESSFULLY!');
        console.log(`⏱️  Total execution time: ${duration} seconds`);
        console.log('📄 Output files generated:');
        console.log('   - permissions-v1.0.json');
        console.log('   - permissions-beta.json');
        resolve();
      } else {
        console.log('❌ PRODUCTION EXTRACTION FAILED');
        console.log(`⏱️  Execution time before failure: ${duration} seconds`);
        reject(new Error(`Extractor exited with code ${code}`));
      }
    });
    
    child.on('error', (error) => {
      console.log('❌ PRODUCTION EXTRACTION ERROR');
      reject(error);
    });
    
    // Handle process termination gracefully
    process.on('SIGINT', () => {
      console.log('\n🛑 Gracefully shutting down...');
      child.kill('SIGTERM');
    });
  });
}

async function main() {
  try {
    // Estimate completion time
    console.log('📊 Estimated completion times (optimized mode):');
    console.log('   - v1.0 (~15,657 methods): 13-15 minutes');
    console.log('   - Beta (~26,949 methods): 22-25 minutes');
    console.log('   - Total estimated: 35-40 minutes');
    console.log('');
    
    await runExtractor(PRODUCTION_ENV);
    
  } catch (error) {
    console.error('💥 Production run failed:', error.message);
    process.exit(1);
  }
}

main().catch(console.error);