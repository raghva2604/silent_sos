#!/usr/bin/env node

/**
 * Interactive Emergency AI CLI
 * Run: node src/emergency-cli.js
 */

const EmergencyAIClient = require('./emergency-ai-client');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const client = new EmergencyAIClient();

console.log('\n╔════════════════════════════════════════════════════╗');
console.log('║     Emergency AI Assistant - Interactive CLI      ║');
console.log('╚════════════════════════════════════════════════════╝\n');

function askQuestion(question) {
  return new Promise(resolve => rl.question(question, resolve));
}

async function main() {
  while (true) {
    console.log('\nOptions:');
    console.log('  1. Send emergency (text)');
    console.log('  2. Send emergency with file');
    console.log('  3. Health check');
    console.log('  4. Exit\n');

    const choice = await askQuestion('Select option (1-4): ');

    if (choice === '4') {
      console.log('\nGoodbye! 👋\n');
      rl.close();
      process.exit(0);
    }

    if (choice === '3') {
      await client.healthCheck();
      continue;
    }

    if (choice === '1') {
      const message = await askQuestion('\nEmergency description: ');
      const language = await askQuestion('Language code (en/es/fr/etc): ');
      const location = await askQuestion('Location: ');

      try {
        const response = await client.sendEmergency(message, {
          language: language || 'en',
          location: location || 'unknown'
        });
        console.log('\n📋 AI Response:');
        console.log('─────────────────────────────────────────────────');
        console.log(response);
        console.log('─────────────────────────────────────────────────');
      } catch (error) {
        console.error('\n✗ Error:', error.message);
      }
    }

    if (choice === '2') {
      const message = await askQuestion('\nEmergency description: ');
      const filePath = await askQuestion('File path: ');
      const language = await askQuestion('Language code (en/es/fr/etc): ');
      const location = await askQuestion('Location: ');

      try {
        const response = await client.sendEmergencyWithFile(message, filePath, {
          language: language || 'en',
          location: location || 'unknown'
        });
        console.log('\n📋 AI Response:');
        console.log('─────────────────────────────────────────────────');
        console.log(response);
        console.log('─────────────────────────────────────────────────');
      } catch (error) {
        console.error('\n✗ Error:', error.message);
      }
    }
  }
}

main();
