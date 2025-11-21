/**
 * Test script for Emergency AI
 * Run: node src/test-emergency.js
 */

const EmergencyAIClient = require('./emergency-ai-client');

async function runTests() {
  console.log('═══════════════════════════════════════════════════');
  console.log('  Emergency AI - VS Code Integration Test Suite');
  console.log('═══════════════════════════════════════════════════\n');

  const client = new EmergencyAIClient();

  // Test 1: Health Check
  console.log('TEST 1: Health Check');
  console.log('─────────────────────────────────────────────────');
  try {
    const health = await client.healthCheck();
    console.log('Result:', health.status);
  } catch (error) {
    console.error('Failed:', error.message);
  }

  // Test 2: Simple Emergency (English)
  console.log('\n\nTEST 2: Simple Emergency (English)');
  console.log('─────────────────────────────────────────────────');
  try {
    const response = await client.sendEmergency(
      'Person collapsed, not breathing, no pulse',
      {
        language: 'en',
        location: 'Office building, 3rd floor'
      }
    );
    console.log('AI Response:');
    console.log(response);
  } catch (error) {
    console.error('Failed:', error.message);
  }

  // Test 3: Multilingual Emergency (Spanish)
  console.log('\n\nTEST 3: Multilingual Emergency (Spanish)');
  console.log('─────────────────────────────────────────────────');
  try {
    const response = await client.sendEmergency(
      'Persona inconsciente, no respira',
      {
        language: 'es',
        location: 'Edificio de oficinas, piso 3'
      }
    );
    console.log('AI Response (should be in Spanish):');
    console.log(response);
  } catch (error) {
    console.error('Failed:', error.message);
  }

  // Test 4: Different Emergency Type
  console.log('\n\nTEST 4: Different Emergency Type (Fire)');
  console.log('─────────────────────────────────────────────────');
  try {
    const response = await client.sendEmergency(
      'Fire in kitchen, smoke spreading rapidly',
      {
        language: 'en',
        location: 'Residential apartment, 5th floor'
      }
    );
    console.log('AI Response:');
    console.log(response);
  } catch (error) {
    console.error('Failed:', error.message);
  }

  // Test 5: With File Upload (if you have a test image)
  console.log('\n\nTEST 5: Emergency with Image Upload');
  console.log('─────────────────────────────────────────────────');
  console.log('Skipped (create test-image.jpg to enable)');
  // Uncomment if you have a test image:
  /*
  try {
    const response = await client.sendEmergencyWithFile(
      'Injury visible in photo',
      './test-image.jpg',
      {
        language: 'en',
        location: 'Home'
      }
    );
    console.log('AI Response:');
    console.log(response);
  } catch (error) {
    console.error('Failed:', error.message);
  }
  */

  console.log('\n═══════════════════════════════════════════════════');
  console.log('  Test Suite Complete');
  console.log('═══════════════════════════════════════════════════\n');
}

// Run tests
runTests().catch(error => {
  console.error('\n✗ Test suite failed:', error);
  process.exit(1);
});
