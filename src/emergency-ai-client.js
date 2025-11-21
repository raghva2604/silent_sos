/**
 * Emergency AI Client for VS Code
 * Handles all communication with n8n webhook
 */

require('dotenv').config();
const fetch = require('node-fetch');
const FormData = require('form-data');
const fs = require('fs');

class EmergencyAIClient {
  constructor() {
    this.apiUrl = process.env.EMERGENCY_AI_API_URL;
    this.apiKey = process.env.EMERGENCY_AI_API_KEY;
    this.timeout = parseInt(process.env.EMERGENCY_AI_TIMEOUT) || 30000;
    this.retryAttempts = parseInt(process.env.EMERGENCY_AI_RETRY_ATTEMPTS) || 3;

    if (!this.apiUrl || !this.apiKey) {
      throw new Error('Missing EMERGENCY_AI_API_URL or EMERGENCY_AI_API_KEY in .env file');
    }

    // Parse API key: support either a token (x-api-key) or username/password pair
    // Format supported for credentials: "username=alice,password=secret"
    this.authHeader = null; // { name, value }
    if (this.apiKey && this.apiKey.includes('username=')) {
      // parse username/password and create Basic auth header
      const parts = this.apiKey.split(',').map(p => p.trim());
      const map = {};
      parts.forEach(p => {
        const [k, v] = p.split('=');
        if (k && v) map[k.trim()] = v.trim();
      });
      if (map.username && map.password) {
        const token = Buffer.from(`${map.username}:${map.password}`).toString('base64');
        this.authHeader = { name: 'Authorization', value: `Basic ${token}` };
      }
    } else if (this.apiKey) {
      // Use x-api-key header by default for token-style keys
      this.authHeader = { name: 'x-api-key', value: this.apiKey };
    }

    console.log('✓ Emergency AI Client initialized');
    console.log(`  URL: ${this.apiUrl}`);
  }

  /**
   * Send text emergency
   */
  async sendEmergency(message, options = {}) {
    const {
      language = 'en',
      location = 'unknown',
      sessionId = this.generateSessionId()
    } = options;

    console.log(`\n🚨 Sending emergency request...`);
    console.log(`  Message: ${message.substring(0, 50)}...`);
    console.log(`  Language: ${language}`);

    const payload = {
      message,
      language,
      location,
      sessionId,
      timestamp: new Date().toISOString()
    };

    return this._makeRequest(payload);
  }

  /**
   * Send emergency with file attachment
   */
  async sendEmergencyWithFile(message, filePath, options = {}) {
    const {
      language = 'en',
      location = 'unknown',
      sessionId = this.generateSessionId()
    } = options;

    console.log(`\n🚨 Sending emergency with file...`);
    console.log(`  Message: ${message}`);
    console.log(`  File: ${filePath}`);

    if (!fs.existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }

    const form = new FormData();
    form.append('message', message);
    form.append('language', language);
    form.append('location', location);
    form.append('sessionId', sessionId);
    form.append('data', fs.createReadStream(filePath));

    return this._makeRequestWithFile(form);
  }

  /**
   * Make HTTP request with retry logic
   */
  async _makeRequest(payload, attempt = 1) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.timeout);

      // Build headers (supports Basic auth or x-api-key)
      const headers = { 'Content-Type': 'application/json' };
      if (this.authHeader) headers[this.authHeader.name] = this.authHeader.value;

      const response = await fetch(this.apiUrl, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
        signal: controller.signal
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorText = await response.text();
        // Try to parse JSON error body for n8n helpful hints
        let parsedError = errorText;
        try {
          const j = JSON.parse(errorText);
          if (j && j.message) parsedError = `${j.message}${j.hint ? ' - ' + j.hint : ''}`;
        } catch (e) {
          // keep raw text
        }

        // If n8n returns webhook not registered, provide a clearer action message
        if (response.status === 404 && String(parsedError).toLowerCase().includes('webhook')) {
          const actionMsg = `n8n webhook not registered (HTTP 404). Ensure the workflow is Active in n8n or use the Test Webhook URL from the node editor.`;
          throw new Error(`HTTP 404: ${parsedError}\nAction: ${actionMsg}`);
        }

        throw new Error(`HTTP ${response.status}: ${parsedError}`);
      }

      const result = await response.text();
      console.log('✓ Response received successfully\n');
      return result;

    } catch (error) {
      console.error(`✗ Attempt ${attempt} failed: ${error.message}`);

      if (attempt < this.retryAttempts && this._shouldRetry(error)) {
        const delay = 1000 * Math.pow(2, attempt - 1); // Exponential backoff
        console.log(`  Retrying in ${delay}ms...`);
        await this._sleep(delay);
        return this._makeRequest(payload, attempt + 1);
      }

      throw error;
    }
  }

  /**
   * Make HTTP request with file upload
   */
  async _makeRequestWithFile(form) {
    try {
      const headers = { ...form.getHeaders() };
      if (this.authHeader) headers[this.authHeader.name] = this.authHeader.value;

      const response = await fetch(this.apiUrl, {
        method: 'POST',
        headers,
        body: form
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`HTTP ${response.status}: ${errorText}`);
      }

      const result = await response.text();
      console.log('✓ File uploaded and response received\n');
      return result;

    } catch (error) {
      console.error(`✗ File upload failed: ${error.message}`);
      throw error;
    }
  }

  /**
   * Check if error is retryable
   */
  _shouldRetry(error) {
    return error.name === 'AbortError' ||
           error.message.includes('ECONNREFUSED') ||
           error.message.includes('ETIMEDOUT') ||
           error.message.includes('HTTP 5');
  }

  /**
   * Generate unique session ID
   */
  generateSessionId() {
    return `vscode-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Sleep utility
   */
  _sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Health check
   */
  async healthCheck() {
    console.log('\n🏥 Running health check...');
    try {
      const response = await this.sendEmergency('Health check', {
        language: 'en',
        location: 'VS Code'
      });
      console.log('✓ Health check passed');
      return { status: 'healthy', response };
    } catch (error) {
      // If error contains actionable advice from n8n, surface it prominently
      if (String(error.message).toLowerCase().includes('n8n webhook not registered')) {
        console.error('\n✗ Health check failed: n8n webhook appears to be unregistered.');
        console.error('  Action: Open your n8n workflow and toggle the webhook node to Active, or use the Test Webhook URL present in the node editor.');
        console.error('  Detailed error:', error.message);
      } else {
        console.error('✗ Health check failed:', error.message);
      }
      return { status: 'unhealthy', error: error.message };
    }
  }
}

module.exports = EmergencyAIClient;
