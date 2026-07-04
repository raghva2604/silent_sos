const geminiClient = require("../ai/gemini");
const { incidentSummaryPrompt } = require("../ai/prompts");

async function generateIncidentSummary(req, res) {
  try {
    const payload = req.body || {};

    const requiredFields = [
      "riskScore",
      "status",
      "battery",
      "speed",
      "fallDetected",
      "latitude",
      "longitude",
    ];

    const missing = requiredFields.filter(
      (field) => payload[field] === undefined || payload[field] === null
    );

    if (missing.length > 0) {
      return res.status(400).json({
        error: `Missing fields: ${missing.join(", ")}`,
      });
    }

    const payloadForPrompt = {
      ...payload,
      location: `${payload.latitude}, ${payload.longitude}`,
    };

    const prompt = incidentSummaryPrompt(payloadForPrompt);

    // Gemini 2.x SDK
    const response = await geminiClient.models.generateContent({
      model: "gemini-2.5-flash",
      contents: prompt,
    });

    const text = (response.text || "").trim();

    if (!text) {
      return res.status(500).json({
        error: "Gemini returned an empty response.",
      });
    }

    // Try parsing JSON returned by Gemini
    try {
      const cleaned = text
        .replace(/```json/g, "")
        .replace(/```/g, "")
        .trim();

      const result = JSON.parse(cleaned);

      return res.status(200).json({
        summary: result.summary || "",
        recommendation: result.recommendation || "",
      });
    } catch (e) {
      // If Gemini responds in plain text
      return res.status(200).json({
        summary: text,
        recommendation: "",
      });
    }
  } catch (error) {
    console.error("Gemini Error:", error);

    return res.status(500).json({
      error: "Unable to generate incident summary.",
      details: error.message,
    });
  }
}

module.exports = {
  generateIncidentSummary,
};