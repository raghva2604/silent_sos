# Emergency AI Assistant - VS Code Integration

Multilingual emergency response AI powered by ChatGPT and n8n.

## Features

- 🌍 20+ language support
- 📸 Image/file upload support
- 🔄 Automatic retry with exponential backoff
- 💾 Conversation memory
- 📊 Emergency records storage

## Setup

1. Install dependencies:
	 ```bash
	 npm install
	 ```

Configure .env:

EMERGENCY_AI_API_URL=https://niha2604.app.n8n.cloud/webhook/emergency-ai
EMERGENCY_AI_API_KEY=your_api_key_here

Run tests:

```bash
npm test
```

## Usage

### Command Line

# Interactive CLI
npm run cli

# Run tests
npm test

# Health check
npm run health

### In Code

```js
const EmergencyAIClient = require('./src/emergency-ai-client');

const client = new EmergencyAIClient();

// Send emergency
const response = await client.sendEmergency(
	'Person collapsed, not breathing',
	{
		language: 'en',
		location: 'Office, 3rd floor'
	}
);

console.log(response);
```

### VS Code Tasks

Press Ctrl+Shift+P → "Tasks: Run Task" → Select:

Emergency AI: Run Tests
Emergency AI: Health Check
Emergency AI: Quick Test

## Supported Languages

English, Spanish, French, German, Italian, Portuguese, Russian, Chinese, Japanese, Korean, Arabic, Hindi, Bengali, Turkish, Vietnamese, Thai, Indonesian, Dutch, Polish, Swedish, Norwegian, Danish, Finnish, Greek, Hebrew, Romanian, Czech, Hungarian, Ukrainian, Persian

## API Reference

### sendEmergency(message, options)
Send text emergency.

Parameters:

- message (string): Emergency description
- options (object):
	- language (string): ISO 639-1 code (default: 'en')
	- location (string): Location details
	- sessionId (string): Optional session ID for conversation memory

Returns: Promise<string> - AI response

### sendEmergencyWithFile(message, filePath, options)
Send emergency with file attachment.

Parameters:

- message (string): Emergency description
- filePath (string): Path to file (image, PDF, etc.)
- options (object): Same as sendEmergency

Returns: Promise<string> - AI response

## Troubleshooting

401 Unauthorized:

Check EMERGENCY_AI_API_KEY in .env

Timeout:

Increase EMERGENCY_AI_TIMEOUT in .env

Connection refused:

Verify n8n workflow is active
Check webhook URL is correct

---

## ✅ **FINAL STEP: Test Everything!**

### **In VS Code Terminal:**

```bash
# 1. Run health check
npm run health

# 2. Run full test suite
npm test

# 3. Try interactive CLI
npm run cli
```

Or use VS Code Tasks:
Press Ctrl+Shift+P (or Cmd+Shift+P on Mac)
Type "Tasks: Run Task"
Select "Emergency AI: Run Tests"

🎯 What You Can Do Now:
Test from Terminal: npm test

Interactive Mode: npm run cli

Use in Your Code:

const EmergencyAIClient = require('./src/emergency-ai-client');
const client = new EmergencyAIClient();
const response = await client.sendEmergency('Emergency!', {language: 'en'});
Create VS Code Extension (optional - let me know if you want this!)
