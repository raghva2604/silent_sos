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

This project no longer includes the Node-based Emergency AI client. The repository now uses a local TensorFlow model for training and inference (integrated into the app or separate training scripts).

If you have TensorFlow training or inference scripts, place them under `src/tf/` or add a new `scripts/` entry and document usage here. Remove any remaining references to the old Node CLI or tests.

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

## Testing & Running

Node-based CLI, tests and health-check were removed because this project now uses a local TensorFlow model. To run model training or inference, add your TensorFlow scripts under `src/tf/` and document commands here (for example: `node src/tf/train.js` or `python src/tf/train.py`).

If you want, I can scaffold a small TF training/inference script and add simple run/test tasks.
