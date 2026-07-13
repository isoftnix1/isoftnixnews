const Groq = require('groq-sdk');

// We initialize inside the functions or with a getter so the app doesn't crash on startup if the key is missing yet.
let groqClient = null;

function getGroqClient() {
  if (!process.env.GROQ_API_KEY) {
    throw new Error('GROQ_API_KEY is not configured in .env');
  }
  if (!groqClient) {
    groqClient = new Groq({ apiKey: process.env.GROQ_API_KEY });
  }
  return groqClient;
}

/**
 * Analyzes the user's natural language command to determine the intent.
 * Returns an object: { intent: 'news' | 'export' | 'equipment' | 'general', date: 'YYYY-MM-DD' }
 */
async function analyzeIntent(command) {
  const groq = getGroqClient();
  const today = new Date().toISOString().split('T')[0];
  
  const prompt = `You are an intelligent agricultural assistant. The current date is ${today}.
The user said: "${command}"

Classify their intent into exactly ONE of the following categories:
- "news": They are asking for the latest news, updates, or information about today/yesterday/etc.
- "export": They want to contact export consultancy, market export people, or export support team.
- "equipment": They are asking for contact numbers for agricultural equipment or machinery.
- "general": They are asking a general farming, crop, or agricultural question.

Also extract the intended date if they are asking for news (otherwise null).
Return ONLY a raw JSON object, nothing else. Do not use markdown blocks.
Format: {"intent": "news|export|equipment|general", "date": "YYYY-MM-DD" | null}`;

  try {
    const chatCompletion = await groq.chat.completions.create({
      messages: [{ role: 'user', content: prompt }],
      model: 'llama-3.1-8b-instant',
      temperature: 0,
    });

    const responseText = chatCompletion.choices[0]?.message?.content?.trim();
    const cleanText = responseText.replace(/```json/g, '').replace(/```/g, '').trim();
    
    console.log(`[AI Service] AnalyzeIntent Input Command: "${command}"`);
    console.log(`[AI Service] AnalyzeIntent Raw Llama Response:`, cleanText);

    const data = JSON.parse(cleanText);
    console.log(`[AI Service] AnalyzeIntent Parsed Result:`, data);

    return {
      intent: data.intent || 'general',
      date: data.date || today
    };
  } catch (error) {
    console.error('[AI Service] Failed to analyze intent:', error);
    return { intent: 'general', date: today };
  }
}

/**
 * Summarizes the articles into a radio script in the requested language.
 */
async function generateVoiceSummary(articles, lang) {
  if (!articles || articles.length === 0) {
    if (lang === 'hi') return "आज के लिए कोई नई खबर नहीं है।";
    if (lang === 'mr') return "आज कोणतीही नवीन बातमी नाही.";
    return "There are no new articles for today.";
  }

  const groq = getGroqClient();
  
  const languageNames = {
    en: 'English',
    hi: 'Hindi',
    mr: 'Marathi'
  };
  const targetLanguage = languageNames[lang] || 'English';

  const articlesText = articles.map((a, idx) => {
    return `Article ${idx + 1} (${a.category_name}): Title: ${a.title} - ${a.content}`;
  }).join('\n\n');

  const prompt = `You are a professional news anchor. I will provide you with top news articles categorized by Agriculture, Technology, Business, and Global.
Your job is to read these and summarize them into a single, cohesive, 1-minute radio news bulletin.
  
RULES:
1. Output the summary strictly in ${targetLanguage}.
2. Do not include any markdown, emojis, or formatting like asterisks. 
3. Output only the spoken text as it should be read by a Text-to-Speech engine.
4. Transition smoothly between categories.

ARTICLES:
${articlesText}`;

  try {
    const chatCompletion = await groq.chat.completions.create({
      messages: [{ role: 'system', content: prompt }],
      model: 'llama-3.1-8b-instant',
      temperature: 0.5,
      max_tokens: 1024,
    });

    return chatCompletion.choices[0]?.message?.content?.trim();
  } catch (error) {
    console.error('[AI Service] Failed to generate summary:', error);
    throw new Error('Failed to generate AI summary');
  }
}

module.exports = {
  analyzeIntent,
  generateVoiceSummary,
};
