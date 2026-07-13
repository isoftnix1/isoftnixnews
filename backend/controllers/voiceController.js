const { pool } = require('../config/db');
const aiService = require('../services/aiService');

const getVoiceSummary = async (req, res) => {
  try {
    const { command, lang = 'en' } = req.body;

    if (!command) {
      console.warn('[AI Voice] Received empty command.');
      return res.status(400).json({ success: false, message: 'Command is required' });
    }

    console.log(`\n================= NEW AI VOICE REQUEST =================`);
    console.log(`[AI Voice] 1. User asked: "${command}" (Language: ${lang})`);

    // 1. Extract intent & Date
    const { intent, date: targetDate } = await aiService.analyzeIntent(command);
    console.log(`[AI Voice] 2. Groq Extracted Intent: ${intent}, Date: ${targetDate}`);

    let aiResponse = '';

    if (intent === 'export') {
      const productionExportContacts = [
        { name: 'Agriculture Export Support', phone: '74474 40801' }
      ];
      const contactsText = productionExportContacts.map(c => `${c.name}: ${c.phone}`).join(', ');
      if (lang === 'hi') {
        aiResponse = `यहाँ निर्यात सलाहकारों के संपर्क नंबर हैं: ${contactsText}`;
      } else if (lang === 'mr') {
        aiResponse = `येथे निर्यात सल्लागारांचे संपर्क क्रमांक आहेत: ${contactsText}`;
      } else {
        aiResponse = `Here are the contact numbers for the Export Consultancy team: ${contactsText}`;
      }
    } else if (intent === 'equipment') {
      const productionEquipmentContacts = [
        { name: 'Agriculture Equipment Support', phone: '+917972420103' }
      ];
      const contactsText = productionEquipmentContacts.map(c => `${c.name}: ${c.phone}`).join(', ');
      if (lang === 'hi') {
        aiResponse = `यहाँ कृषि उपकरण प्रदाताओं के संपर्क नंबर हैं: ${contactsText}`;
      } else if (lang === 'mr') {
        aiResponse = `येथे कृषी उपकरणे पुरवठादारांचे संपर्क क्रमांक आहेत: ${contactsText}`;
      } else {
        aiResponse = `Here are the contact numbers for agricultural equipment providers: ${contactsText}`;
      }
    } else if (intent === 'news') {
      // 2. Define the target categories
      const targetCategories = ['Agriculture', 'Technology', 'Business', 'Global'];
      const articles = [];
      console.log(`[AI Voice] 3. Fetching top 4 articles for this date...`);

      // 3. Fetch 1 top article for each category on the target date
      for (const catName of targetCategories) {
        const query = `
          SELECT 
            n.id, 
            n.title_${lang} AS title, 
            n.content_${lang} AS content,
            c.name_en AS category_name
          FROM news n
          JOIN news_categories nc ON n.id = nc.news_id
          JOIN categories c ON nc.category_id = c.id
          WHERE c.name_en ILIKE $1
            AND n.is_published = true
            AND n.created_at >= $2::date
            AND n.created_at < ($2::date + INTERVAL '1 day')
          ORDER BY n.created_at DESC
          LIMIT 1
        `;
        const result = await pool.query(query, [`%${catName}%`, targetDate]);
        if (result.rows.length > 0) {
          articles.push(result.rows[0]);
        }
      }

      console.log(`[AI Voice] 4. Found ${articles.length} articles. Requesting summary from Groq...`);
      aiResponse = await aiService.generateVoiceSummary(articles, lang);
      aiResponse = aiResponse.replace(/[*#\-_]/g, '').trim(); // Remove formatting marks
      console.log(`[AI Voice] 5. Groq Summary ready. Sending to client.`);
    } else {
      // General Intent
      if (lang === 'hi') {
        aiResponse = "मैं एक कृषि सहायक हूँ। मैं आपको समाचार बता सकता हूँ या निर्यात और उपकरणों के संपर्क दे सकता हूँ।";
      } else if (lang === 'mr') {
        aiResponse = "मी एक कृषी सहाय्यक आहे. मी तुम्हाला बातम्या सांगू शकतो किंवा निर्यात आणि उपकरणांचे संपर्क देऊ शकतो.";
      } else {
        aiResponse = "I am an agricultural assistant. I can provide news summaries or contact details for export and equipment.";
      }
    }

    res.json({
      success: true,
      data: {
        date: targetDate,
        summary: aiResponse
      }
    });

  } catch (error) {
    console.error('[VoiceController] Error generating voice summary:', error);
    res.status(500).json({ success: false, message: 'Failed to generate voice summary' });
  }
};

module.exports = {
  getVoiceSummary,
};
