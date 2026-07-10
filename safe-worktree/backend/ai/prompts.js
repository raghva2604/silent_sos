function incidentSummaryPrompt(data) {
  const { riskScore, status, battery, speed, fallDetected, location } = data;

  return `You are an AI assistant for an incident monitoring system.
You will produce a concise incident summary and recommendation.

Data:
- Risk score: ${riskScore}
- Status: ${status}
- Battery: ${battery}%
- Speed: ${speed} km/h
- Fall detected: ${fallDetected}
- Location: ${location}

Provide a short summary with a clear recommendation. Use bullet points for the reason section.
Output only a JSON object with keys: summary, recommendation.
`;
}

module.exports = {
  incidentSummaryPrompt,
};
