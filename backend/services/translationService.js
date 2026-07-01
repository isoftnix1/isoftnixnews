const TRANSLATION_SERVICE_URL = process.env.TRANSLATION_SERVICE_URL || 'http://localhost:8000';
const TRANSLATION_TIMEOUT = parseInt(process.env.TRANSLATION_TIMEOUT, 10) || 120000;
let isTranslationEnabled = false;

async function checkHealth() {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);
    const response = await fetch(`${TRANSLATION_SERVICE_URL}/health`, { signal: controller.signal });
    clearTimeout(timeout);
    
    if (response.ok) {
      isTranslationEnabled = true;
      console.log('Translation Service available. Translation enabled.');
    } else {
      console.error('Translation Service unhealthy. Serving English only.');
    }
  } catch (error) {
    console.error('Translation Service Unavailable. Serving English only.');
  }
}

async function translate(text, sourceLanguage, targetLanguage) {
  if (!isTranslationEnabled) return text;
  if (!text) return text;
  if (sourceLanguage === targetLanguage) return text;
  if (targetLanguage === 'en') return text;

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), TRANSLATION_TIMEOUT);

    const response = await fetch(`${TRANSLATION_SERVICE_URL}/translate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        text,
        source_language: sourceLanguage,
        target_language: targetLanguage
      }),
      signal: controller.signal
    });

    clearTimeout(timeout);

    if (!response.ok) {
      console.error(`Translation service error: ${response.statusText}`);
      return text;
    }

    const data = await response.json();
    return data.translated_text || text;
  } catch (error) {
    if (error.name === 'AbortError') {
      console.error(`Translation timeout after ${TRANSLATION_TIMEOUT} ms.\nReturning original English content.`);
    } else {
      console.error('Translation service unavailable:', error.message);
    }
    return text; // Return English on failure
  }
}

module.exports = {
  translate,
  checkHealth,
};
