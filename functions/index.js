const { setGlobalOptions } = require("firebase-functions/v2");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

setGlobalOptions({ maxInstances: 10 });

async function callGemini(models, body, apiKey) {
  let lastError = null;

  for (const model of models) {
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        logger.info(`Trying ${model}, attempt ${attempt}`);

        const response = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": apiKey,
            },
            body: JSON.stringify(body),
          }
        );

        if (response.ok) {
          logger.info(`Gemini success with model: ${model}`);
          return await response.json();
        }

        const errorText = await response.text();
        lastError = errorText;

        logger.error(`Gemini error from ${model}`, {
          status: response.status,
          attempt,
          error: errorText,
        });

        if (
          response.status !== 503 &&
          response.status !== 429 &&
          response.status !== 404
        ) {
          throw new Error(errorText);
        }

        if (attempt < 3) {
          await new Promise((resolve) =>
            setTimeout(resolve, 2000 * attempt)
          );
        }
      } catch (e) {
        lastError = e.message;

        logger.error(`Gemini exception from ${model}`, {
          attempt,
          error: e.message,
        });

        if (attempt < 3) {
          await new Promise((resolve) =>
            setTimeout(resolve, 2000 * attempt)
          );
        }
      }
    }
  }

  throw new Error(lastError || "All Gemini models failed");
}

async function callOpenAI(prompt, schema, apiKey) {
  const response = await fetch(
    "https://api.openai.com/v1/chat/completions",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        messages: [
          {
            role: "system",
            content: `
You must return only valid JSON.
Do not use markdown.
Do not use code blocks.
Do not explain anything.
Return only a JSON object matching the requested schema.
    `,
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        temperature: 0.1,
      }),
    }
  );

  const responseText = await response.text();

  if (!response.ok) {
    logger.error("OpenAI error", {
      status: response.status,
      error: responseText,
    });

    throw new Error(responseText);
  }

  const parsed = JSON.parse(responseText);

  logger.info("OpenAI full parsed response", {
    parsed,
  });

  const text = parsed.choices?.[0]?.message?.content || "{}";

  let parsedResult;

  try {
    parsedResult = JSON.parse(text);
  } catch (e) {
    logger.error("Failed to parse OpenAI content", {
      text,
      error: e.message,
    });

    throw new Error("OpenAI returned invalid JSON content");
  }

  parsedResult.score ??= 0;
  parsedResult.level ??= "";
  parsedResult.summary ??= "";
  parsedResult.correctedText ??= "";
  parsedResult.topicRelevance ??= "";
  parsedResult.topicScore ??= 0;
  parsedResult.topicComment ??= "";
  parsedResult.mistakes ??= [];

  parsedResult.mistakes = (parsedResult.mistakes || []).map((m) => ({
    original: m.original || m.text || "",
    corrected: m.corrected || m.correct || "",
    category: m.category || "Орфография",
    explanation: m.explanation || "",
  }));

  return {
    candidates: [
      {
        content: {
          parts: [
            {
              text: JSON.stringify(parsedResult),
            },
          ],
        },
      },
    ],
  };
}

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
      uiLanguage: request.data?.uiLanguage || null,
    });

    try {
      const essay = request.data?.essay?.toString().trim() || "";
      const targetLevel = request.data?.targetLevel?.toString() || "B2";
      const topic = request.data?.topic?.toString() || "";
      const uiLanguage = request.data?.uiLanguage?.toString() || "ru";

      if (!essay) {
        throw new HttpsError("invalid-argument", "Essay is empty");
      }

      const apiKey = process.env.GEMINI_API_KEY;

      if (!apiKey) {
        throw new HttpsError("internal", "Missing GEMINI_API_KEY");
      }

      const feedbackLanguage =
        uiLanguage === "ky" ? "Kyrgyz" : "Russian";

      const prompt = `
Сен кыргыз тили боюнча жазуу текшерүүчү адиссиң.
Окуучунун кыргыз тилиндеги эссесин текшерип, ЖАЛАҢ ГАНА туура JSON кайтар.

Деңгээли: ${targetLevel}
Тема: ${topic}

Эссе ар дайым кыргыз тилинде жазылат.

Бардык комментарийлерди жана түшүндүрмөлөрдү ${feedbackLanguage} тилинде жаз.

МААНИЛҮҮ:
- Эссе дайыма кыргыз тилинде жазылат
- Эч качан башка тилди талап кылба
- correctedText талаасында оригинал тексттин оңдолгон кыргызча версиясы болушу керек
- correctedText толугу менен кыргыз тилинде болушу керек
- Кыргыз тилиндеги грамматикалык, орфографиялык, пунктуациялык жана сөз байлыгы боюнча каталарды тап
- Эгер тема туура келбесе дагы, тилдик каталарды баары бир текшер
- level талаасы төмөнкүлөрдүн бири болушу керек: A1, A2, B1, B2, C1
- Бардык summary, topicComment, explanation жана башка комментарийлер ${feedbackLanguage} тилинде болсун
- Баа бергенде абдан так жана туруктуу бол
- Ар дайым бирдей стандарттарды колдон
- Эссе чындап эле B2 деңгээлиндеги сөз байлыгына жана түзүлүшүнө туура келсе гана B2 деп баала
- Эгер эки деңгээлдин ортосунда күмөн болсоң, төмөнкү деңгээлди танда
- Өтө начар эсселерге 0-2 упай бер
- Көп катасы бар жөнөкөй эсселерге 3-4 упай бер
- Орточо, бирок айрым каталары бар эсселерге 5-6 упай бер
- Аз катасы бар жакшы эсселерге 7-8 упай бер
- Бай сөз байлыгы бар жана дээрлик катасыз эң мыкты эсселерге гана 9-10 упай бер
- Бир эле катаны эки жолу кайталаба
- Болгону уникалдуу каталарды көрсөт
- Максимум 5 ката көрсөт
- Эгер эссе темага туура келбесе, себебин түшүндүр
- Эгер текстте ачык көрүнгөн каталар болсо, кеминде 1 ката сөзсүз кайтар
- Чыныгы грамматикалык, орфографиялык, пунктуациялык жана сөз колдонуудагы каталарды гана көрсөт
- Стилди жакшыртуу боюнча сунуштарды ката катары көрсөтпө
- Эгер сөз айкашы грамматикалык жактан туура болсо, аны ката деп белгилебе
- Эгер сүйлөм түшүнүктүү жана табигый болсо, аны ката деп эсептебе
- Эгер чыныгы ката жок болсо, mistakes массивин бош кайтар
- Болгону тизмени толтуруш үчүн жасалма ката ойлоп таппа

Tasks:
1. 0дон 10го чейин баа бер
2. Окуучунун деңгээлин аныкта
3. Эссени кыргыз тилинде оңдоп бер
4. Кыскача комментарий жаз
5. Кыргыз тилиндеги каталарды түшүндүрмө менен көрсөт
6. Эссе темага канчалык туура келгенин текшер
7. Окуучу темага толук, жарым-жартылай же такыр жооп бербегенин түшүндүр
8. Төмөнкүлөргө көңүл бур:
   - грамматика
   - орфография
   - пунктуация
   - сүйлөм түзүлүшү
   - сөз байлыгы
   - темага ылайыктуулугу

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
                explanation: { type: "string" },
              },
              required: [
                "original",
                "corrected",
                "category",
                "explanation",
              ],
            },
          },
        },
        required: [
          "score",
          "level",
          "summary",
          "correctedText",
          "topicRelevance",
          "topicScore",
          "topicComment",
          "mistakes",
        ],
      };

      const requestBody = {
        systemInstruction: {
          parts: [
            {
              text: "Return only JSON. No markdown. No explanation outside JSON.",
            },
          ],
        },
        contents: [
          {
            parts: [{ text: prompt }],
          },
        ],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: schema,
          temperature: 0.1,
        },
      };

      let data;

      try {
        data = await callGemini(
          [
            "gemini-2.5-flash",
            "gemini-2.0-flash",
          ],
          requestBody,
          apiKey
        );
      } catch (geminiError) {
        logger.error("Gemini failed, fallback to OpenAI", geminiError);

        const openAiKey = process.env.OPENAI_API_KEY;

        if (!openAiKey) {
          throw new HttpsError(
            "unavailable",
            "Missing OPENAI_API_KEY"
          );
        }

        data = await callOpenAI(
          prompt,
          schema,
          openAiKey
        );
      }

      let text = data?.candidates?.[0]?.content?.parts?.[0]?.text;

      if (!text && data?.choices?.[0]?.message?.content) {
        text = data.choices[0].message.content;
      }

      logger.info("AI raw response", { text });

      if (!text) {
        throw new HttpsError("internal", "Empty AI response");
      }

      try {
        return JSON.parse(text);
      } catch (parseError) {
        logger.error("JSON parse failed", {
          text,
          error: parseError.message,
        });

        throw new HttpsError(
          "internal",
          "AI returned invalid JSON"
        );
      }
    } catch (e) {
      logger.error("checkEssay failed", e);

      if (e instanceof HttpsError) {
        throw e;
      }

      throw new HttpsError(
        "internal",
        e.message || "Unknown error"
      );
    }
  }
);

