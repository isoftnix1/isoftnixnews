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

function getAppaPersonaPrompt(targetLanguage) {
  return `You are Appa, a highly intelligent, conversational AI Voice Agent inside the "Updates" app.

PERSONALITY:
You are Friendly, Funny, Caring, Intelligent, Calm, Helpful, Positive, Human-like, and Respectful. You feel like a close friend who enjoys explaining news.
NEVER sound robotic, like Google Assistant, or Alexa. Never sound like a text reader.

VOICE STYLE:
Speak naturally in ${targetLanguage}.
Do NOT read articles word-for-word. Explain them conversationally. Keep facts accurate. Tell the listener why it matters. End positively.
Use natural pauses and contractions. Speak slowly and clearly.

GREETINGS:
If the user says "Appa", "Hi Appa", "Hello Appa", or "Hey Appa", or if this is the start of a conversation, respond with a friendly, random greeting in ${targetLanguage}.
- English examples: "Hello! I'm Appa. Let's chat.", "Hey! I'm Appa. Ready for today's updates?", "Welcome back! I'm Appa."
- Hindi examples: "नमस्कार! मैं हूँ अप्पा। चलिए बातें करते हैं।", "नमस्ते! मैं हूँ अप्पा। आज की खबरें देखते हैं।", "स्वागत है! मैं हूँ अप्पा।"
- Marathi examples: "नमस्कार! मी आहे अप्पा. चला मारू गप्पा!", "नमस्कार! मी आहे अप्पा. आज काय नवीन जाणून घ्यायचं?", "हॅलो! मी आहे अप्पा. चला आजच्या बातम्या पाहूया.", "स्वागत आहे! मी आहे अप्पा. तुमचा मित्र."
Rotate greetings randomly. Never repeat the exact same greeting every time.

HUMOR:
Occasionally include ONE light family-friendly joke (e.g., "Our mangoes are becoming international celebrities.").
ABSOLUTE BAN: Never joke about death, farmer losses, floods, drought, politics, religion, or accidents.

STRICT SAFETY RESTRICTION: 
1. EXTREME DANGER BAN: You must absolutely REFUSE to engage in, joke about, or discuss violence, murder, severe crimes, self-harm, or illegal activities under ANY circumstances.
2. If the user asks you to roast, joke about, or make fun of a particular person, you are ALLOWED to do so playfully and humorously, exactly like a familiar friend would. Keep the roast funny, witty, and culturally relevant (especially in Marathi or Hindi). However, DO NOT cross the line into physical threats, murder, or extreme hate speech.

ANTI-HALLUCINATION & ACCURACY RULES:
1. If you do not know the exact answer to a question, DO NOT guess or make up facts. Politely admit that you do not know.
2. If the user asks for real-time live data (like today's live weather temperature, live stock prices, or live sports scores) which you do not have access to, politely explain that you don't have live access to that specific data right now.
3. Always answer confidently but honestly. Be concise and to the point.
4. You are a general-purpose assistant. You MUST answer EVERY type of question the user asks (e.g., science, history, cooking, coding, math, general knowledge, entertainment), even if it is completely unrelated to news or agriculture. Be helpful and answer anything they ask.

FORMATTING:
Respond in plain, conversational text. DO NOT use any markdown formatting (no asterisks, bold, or bullet points) because this text will be read aloud by a Text-to-Speech engine.`;
}

/**
 * Analyzes the user's natural language command to determine the intent.
 */
async function analyzeIntent(command, history = []) {
  const groq = getGroqClient();
  const today = new Date().toISOString().split('T')[0];
  
  const historyText = history.slice(-4).map(m => `${m.sender.toUpperCase()}: ${m.content}`).join('\n');

  const prompt = `You are an intelligent intent analyzer. The current date is ${today}.
  
${historyText ? `Recent Chat Context:\n${historyText}\n\n` : ''}The user said: "${command}"

Note: The user's command may be in English, Hindi, or Marathi.
- Words like "news", "न्यूज़", "बातम्या", "खबर", "अपडेट" all mean they want "news".
- Words like "export", "निर्यात" all mean "export".
- Words like "equipment", "उपकरण", "मशीन" all mean "equipment".

Classify their intent into exactly ONE of the following categories:
- "news": They are asking for the latest news, updates, or information about today/yesterday/etc.
- "export": They want to contact export consultancy, market export people, or export support team.
- "equipment": They are asking for contact numbers for agricultural equipment or machinery.
- "general": Any other question, including casual chat, follow-ups, weather/climate ("वातावरण", "मौसम"), entertainment/songs ("सॉन्ग", "गाने", "song"), general knowledge, or if the request is ambiguous/unclear.

Also extract the intended date if they are asking for news (otherwise null).
If the intent is "news", also extract the specific category they are asking for: "Agriculture", "Technology", "Business", "Global", or "all" (if they just ask for general news).
Note for Categories (match these even if they have grammar suffixes like 'ची', 'चा', 'के', 'की'): 
- "Agriculture" includes: "Agriculture", "farming", "कृषि", "खेती", "खेतीबाड़ी", "किसान", "शेती", "शेतकरी", "कृषी"
- "Technology" includes: "Technology", "tech", "प्रौद्योगिकी", "तकनीक", "टेक्नोलॉजी", "तंत्रज्ञान"
- "Business" includes: "Business", "economy", "market", "व्यापार", "व्यवसाय", "कारोबार", "बिज़नेस", "उद्योग", "धंदा", "व्यापाराची", "व्यवसायाची"
- "Global" includes: "Global", "world", "international", "वैश्विक", "दुनिया", "विश्व", "अंतर्राष्ट्रीय", "जागतिक", "आंतरराष्ट्रीय", "जग", "जगाची", "ग्लोबल"
- "all": If they just ask for general news (e.g. "न्यूज़", "खबर", "बातम्या") and DO NOT explicitly mention any of the specific topics above, you MUST set the category to "all".

EXAMPLES:
User: "अप्पा आज के व्यापार की न्यूज़ बताइए"
Output: {"intent": "news", "category": "Business", "date": "${today}"}

User: "आजची जागतिक न्यूज सांगा"
Output: {"intent": "news", "category": "Global", "date": "${today}"}

User: "अप्पा आज की न्यूज़ बताइए"
Output: {"intent": "news", "category": "all", "date": "${today}"}

User: "पुणे का वातावरण कैसा है?"
Output: {"intent": "general", "category": "all", "date": null}

Return ONLY a raw JSON object, nothing else. Do not use markdown blocks.
Format: {"intent": "news|export|equipment|general", "category": "Agriculture|Technology|Business|Global|all", "date": "YYYY-MM-DD" | null}`;

  try {
    const chatCompletion = await groq.chat.completions.create({
      messages: [{ role: 'user', content: prompt }],
      model: 'meta-llama/llama-4-scout-17b-16e-instruct',
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
      category: data.category || 'all',
      date: data.date || today
    };
  } catch (error) {
    console.error('[AI Service] Failed to analyze intent:', error);
    return { intent: 'general', category: 'all', date: today };
  }
}

/**
 * Summarizes the articles into a conversational news bulletin.
 */
async function generateVoiceSummary(articles, lang, requestedCategory = 'all', history = []) {
  const groq = getGroqClient();
  
  const languageNames = {
    en: 'English',
    hi: 'Hindi',
    mr: 'Marathi'
  };
  const targetLanguage = languageNames[lang] || 'English';

  const systemPrompt = `${getAppaPersonaPrompt(targetLanguage)}
  
CONTEXT MEMORY:
You are in an ongoing conversation with the user. Maintain context. 
If the user asks for news and there are no articles, politely inform them in ${targetLanguage} that there are no updates for that specific category today.

NEWS EXPERIENCE:
Whenever you read a news article:
1. Greet the user.
2. Introduce the news.
3. Explain it naturally as a friend.
4. Tell why it matters.
5. Explain how it impacts farmers, businesses, exporters or consumers whenever applicable.
6. Give a short positive takeaway.
7. End with ONE follow-up question (e.g., "Would you like to hear another news update?", "Should I continue with the next story?", "Would you like a quick summary?").

SPECIFIC NEWS RULES:
- EXPORT / IMPORT NEWS: Always explain Farmer impact, Export impact, Business impact, and Global market impact.
- MARKET NEWS: Always explain Price increase/decrease, Market trend, and Farmer impact.`;

  const messages = [{ role: 'system', content: systemPrompt }];
  
  if (history && history.length > 0) {
    history.forEach(msg => {
      messages.push({ role: msg.sender === 'ai' ? 'assistant' : 'user', content: msg.content });
    });
  }


  if (!articles || articles.length === 0) {
    messages.push({ role: 'user', content: `The user asked for ${requestedCategory} news, but there are 0 articles in the database for today. Please tell the user conversationally that there is no news available for this topic today.` });
  } else {
    const articlesText = articles.map((a, idx) => {
      const safeContent = a.content ? a.content.substring(0, 600) + (a.content.length > 600 ? '...' : '') : '';
      return `Article ${idx + 1} (${a.category_name}): Title: ${a.title} - ${safeContent}`;
    }).join('\n\n');

    messages.push({ role: 'user', content: `The user asked for ${requestedCategory} news. Please summarize these top news articles conversationally based on your news experience rules:\n\n${articlesText}` });
  }

  try {
    const chatCompletion = await groq.chat.completions.create({
      messages: messages,
      model: 'meta-llama/llama-4-scout-17b-16e-instruct',
      temperature: 0.7,
      max_tokens: 1024,
    });

    return chatCompletion.choices[0]?.message?.content?.trim();
  } catch (error) {
    console.error('[AI Service] Failed to generate summary:', error);
    throw new Error('Failed to generate AI summary');
  }
}

/**
 * Answers a general knowledge or casual chat question using the Llama 3.1 8B model.
 */
async function answerGeneralQuestion(question, lang, history = [], contextArticles = []) {
  // Hardcoded interceptor for Wake Word / Greeting
  const cleanQ = question.trim().toLowerCase().replace(/[.,!?'"|]/g, '');
  const isGreeting = 
    cleanQ === 'appa' || 
    cleanQ === 'hi appa' || 
    cleanQ === 'hello appa' || 
    cleanQ === 'hey appa' ||
    cleanQ === 'अप्पा' ||
    cleanQ === 'नमस्ते अप्पा' ||
    cleanQ === 'नमस्कार अप्पा' ||
    cleanQ === 'हाय अप्पा' ||
    cleanQ === 'namaste appa' ||
    cleanQ === 'namaskar appa';

  if (isGreeting) {
    console.log(`[AI Service] Exact Wake Word detected. Returning hardcoded greeting.`);
    if (lang === 'hi') {
      return "नमस्कार, मैं आप्पा, चलिए करते हैं गप्पा";
    } else if (lang === 'mr') {
      return "नमस्कार! मी आहे अप्पा, चला मारू गप्पा";
    } else {
      return "Hello! I am Appa, let's chat.";
    }
  }

  const groq = getGroqClient();
  
  const languageNames = {
    en: 'English',
    hi: 'Hindi',
    mr: 'Marathi'
  };
  const targetLanguage = languageNames[lang] || 'English';

  let newsContextStr = '';
  if (contextArticles && contextArticles.length > 0) {
    const articlesText = contextArticles.map((a, idx) => {
      const safeContent = a.content ? a.content.substring(0, 400) + '...' : '';
      return `[Article ${idx + 1}]: ${a.title} - ${safeContent}`;
    }).join('\n\n');
    
    newsContextStr = `
DATABASE NEWS CONTEXT:
Here are the latest news articles from our platform database. 
PRIORITY RULE: If the user's question can be answered using this data, you MUST use this data to answer it accurately. If the question is about general knowledge or a topic not covered in this data, ignore this data and use your general intelligence to answer.
${articlesText}
`;
  }

  const systemPrompt = `${getAppaPersonaPrompt(targetLanguage)}
  
CONTEXT MEMORY:
You are in an ongoing conversation with the user. Maintain context. If the user says "Explain again" or "What does that mean?", refer to the previous messages to understand what they are talking about.
Respond naturally to everyday casual conversation (like "Good Morning", "Thank You", "Bye").
${newsContextStr}`;

  const messages = [{ role: 'system', content: systemPrompt }];
  
  if (history && history.length > 0) {
    history.forEach(msg => {
      messages.push({ role: msg.sender === 'ai' ? 'assistant' : 'user', content: msg.content });
    });
  }

  console.log(`[AI Service] Answering General Question: "${question}"`);
  console.log(`[AI Service] Appa is remembering ${history.length} previous messages for context.`);

  messages.push({ role: 'user', content: question });

  try {
    const chatCompletion = await groq.chat.completions.create({
      messages: messages,
      model: 'llama-3.1-8b-instant',
      temperature: 0.7,
      max_tokens: 512,
    });

    return chatCompletion.choices[0]?.message?.content?.trim();
  } catch (error) {
    console.error('[AI Service] Failed to answer general question:', error);
    if (lang === 'hi') return "मुझे इस प्रश्न का उत्तर देने में समस्या आ रही है।";
    if (lang === 'mr') return "मला या प्रश्नाचे उत्तर देण्यात अडचण येत आहे.";
    return "I am having trouble answering this question right now.";
  }
}

async function generateGrandSummary(voiceHistory, chatHistory, lang) {
  const groq = getGroqClient();
  const today = new Date().toISOString().split('T')[0];

  const languageNames = {
    en: 'English',
    hi: 'Hindi',
    mr: 'Marathi'
  };
  const targetLanguage = languageNames[lang] || 'English';

  const systemPrompt = `You are an AI tasked with maintaining a continuously updated Master Summary of a user's history.
Today is ${today}.
You will be given the user's past historical summary (if any) along with their new voice and text interactions for today.
Write a single, concise paragraph in ${targetLanguage} that merges the past history with today's new interactions into ONE cohesive summary.
CRITICAL REQUIREMENT: You MUST start the summary by explicitly mentioning the "as of" date (e.g., "Continuous Summary as of ${today}: ...").
Do not list every single message. Combine the old summary and new context into a high-level overview.
Keep it strictly under 3 sentences. No conversational filler, just the summary.`;

  let historyText = '';
  if (voiceHistory && voiceHistory.length > 0) {
    historyText += "--- VOICE HISTORY ---\n";
    historyText += voiceHistory.map(m => `User: ${m.user}\nAppa: ${m.ai}`).join('\n\n') + '\n\n';
  }
  if (chatHistory && chatHistory.length > 0) {
    historyText += "--- CHAT HISTORY ---\n";
    historyText += chatHistory.map(m => `${m.sender.toUpperCase()}: ${m.content}`).join('\n') + '\n\n';
  }

  if (!historyText.trim()) {
    return lang === 'mr' ? 'आज कोणतीही चर्चा झाली नाही.' : lang === 'hi' ? 'आज कोई बातचीत नहीं हुई।' : 'No conversations happened today.';
  }

  const messages = [
    { role: 'system', content: systemPrompt },
    { role: 'user', content: `Here is the interaction history for today:\n${historyText}` }
  ];

  try {
    const chatCompletion = await groq.chat.completions.create({
      messages: messages,
      model: 'llama-3.1-8b-instant',
      temperature: 0.3,
      max_tokens: 256,
    });

    return chatCompletion.choices[0]?.message?.content?.trim();
  } catch (error) {
    console.error('[AI Service] Failed to generate grand summary:', error);
    return lang === 'mr' ? 'आजच्या चर्चेचा सारांश.' : lang === 'hi' ? 'आज की बातचीत का सारांश।' : 'Summary of today\'s conversation.';
  }
}

module.exports = {
  analyzeIntent,
  generateVoiceSummary,
  answerGeneralQuestion,
  generateGrandSummary,
};
