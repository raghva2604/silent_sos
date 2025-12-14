#!/usr/bin/env node
/**
 * Production-ready backend server wrapper with diagnostics
 */

console.log('=== Backend Server Startup ===');
console.log('Starting at:', new Date().toISOString());
console.log('Node version:', process.version);
console.log('Working directory:', process.cwd());

// Import the main server
try {
  console.log('Loading server.js...');
  require('./server.js');
  console.log('Server.js loaded successfully');
  
  // Give the server time to start
  setTimeout(() => {
    const http = require('http');
    http.get('http://localhost:3000/health', (res) => {
      console.log('✓ Health check successful:', res.statusCode);
      process.exit(0);
    }).on('error', (err) => {
      console.warn('Health check failed (expected if just started):', err.code);
    });
  }, 2000);
} catch (err) {
  console.error('✗ Failed to start server:', err);
  process.exit(1);
}

// Keep process alive
setInterval(() => {}, 1000);
