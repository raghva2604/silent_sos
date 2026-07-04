const { GoogleGenAI } = require('@google/genai');

const geminiClient = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY,
});

module.exports = geminiClient;
