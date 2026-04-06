const { setGlobalOptions } = require("firebase-functions/v2");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

setGlobalOptions({ maxInstances: 10 });

exports.checkEssay = onCall(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    logger.info("checkEssay START", {
      hasData: !!request.data,
      essayLength: request.data?.essay?.length || 0,
      targetLevel: request.data?.targetLevel || null,
    });

  try {
    const essay = request.data?.essay?.toString().trim() || "";
    const targetLevel = request.data?.targetLevel?.toString() || "B2";
    const topic = request.data?.topic?.toString() || "";

    if (!essay) {
      throw new HttpsError("invalid-argument", "Essay is empty");
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new HttpsError("internal", "Missing GEMINI_API_KEY");
    }

    const prompt = `
You are an English writing examiner.
Analyze the student's essay and return ONLY valid JSON.

Target CEFR level: ${targetLevel}
Topic: ${topic}

Tasks:
1. Give overall score from 0 to 10
2. Estimate CEFR level
3. Correct the essay
4. Give short feedback in Russian
5. Extract mistakes with explanations in Russian
6. Check whether the essay is relevant to the topic
7. Explain briefly in Russian whether the student answered the topic fully, partially, or not really

Essay:
"""${essay}"""
`;

    const schema = {
  type: "object",
  properties: {
    score: { type: "integer" },
    level: { type: "string" },
    summary: { type: "string" },
    correctedText: { type: "string" },

    topicRelevance: { type: "string" },
    topicScore: { type: "integer" },
    topicComment: { type: "string" },

    mistakes: {
      type: "array",
      items: {
        type: "object",
        properties: {
          original: { type: "string" },
          corrected: { type: "string" },
          category: { type: "string" },
          explanation: { type: "string" }
        },
        required: ["original", "corrected", "category", "explanation"]
      }
    }
  },
  required: [
    "score",
    "level",
    "summary",
    "correctedText",
    "topicRelevance",
    "topicScore",
    "topicComment",
    "mistakes"
  ]
};

    const response = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey
        },
        body: JSON.stringify({
          systemInstruction: {
            parts: [
              {
                text: "Return only JSON. No markdown. No explanation outside JSON."
              }
            ]
          },
          contents: [
            {
              parts: [{ text: prompt }]
            }
          ],
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: schema,
            temperature: 0.2
          }
        })
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      logger.error("Gemini API error:", errorText);
      throw new HttpsError("internal", errorText);
    }

    const data = await response.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!text) {
      throw new HttpsError("internal", "Empty AI response");
    }

    return JSON.parse(text);
  } catch (e) {
    logger.error("checkEssay failed", e);
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("internal", e.message || "Unknown error");
  }
});