const { pool } = require('../config/db');
const aiService = require('../services/aiService');

const productionExportContacts = [
  { name: 'Agriculture Export Support', phone: '74474 40801' }
];

const productionEquipmentContacts = [
  { name: 'Omkar Sawant', phone: '+917972420103' }
];

const sendMessage = async (req, res) => {
  try {
    const { message, lang = 'en', conversationId } = req.body;
    const userId = req.user.id; // From authMiddleware

    console.log(`[ChatController] Received message: "${message}", lang: ${lang}, userId: ${userId}, conversationId: ${conversationId}`);

    if (!message) {
      console.warn(`[ChatController] Message is required`);
      return res.status(400).json({ success: false, message: 'Message is required' });
    }

    let activeConversationId = conversationId;

    // 1. If no conversationId, create one
    if (!activeConversationId) {
      console.log(`[ChatController] No active conversationId. Creating a new one.`);
      const convResult = await pool.query(
        'INSERT INTO conversations (user_id, title) VALUES ($1, $2) RETURNING id',
        [userId, message.substring(0, 50)]
      );
      activeConversationId = convResult.rows[0].id;
      console.log(`[ChatController] Created new conversationId: ${activeConversationId}`);
    }

    // 2. Fetch previous conversation history (last 10 messages)
    const historyResult = await pool.query(
      'SELECT sender, content FROM (SELECT sender, content, created_at FROM messages WHERE conversation_id = $1 ORDER BY created_at DESC LIMIT 10) sub ORDER BY created_at ASC',
      [activeConversationId]
    );
    const history = historyResult.rows;

    // 3. Save user message
    await pool.query(
      'INSERT INTO messages (conversation_id, sender, content) VALUES ($1, $2, $3)',
      [activeConversationId, 'user', message]
    );

    // 4. Analyze Intent
    console.log(`[ChatController] Analyzing intent...`);
    const { intent, date } = await aiService.analyzeIntent(message, history);
    console.log(`[ChatController] AI intent: ${intent}, date: ${date}`);
    let aiResponse = '';

    // 5. Handle based on intent
    if (intent === 'export') {
      const contactsText = productionExportContacts.map(c => `${c.name}: ${c.phone}`).join('\n');
      if (lang === 'hi') {
        aiResponse = `यहाँ निर्यात सलाहकारों के संपर्क नंबर हैं:\n${contactsText}\nकृपया अधिक जानकारी के लिए उनसे संपर्क करें।`;
      } else if (lang === 'mr') {
        aiResponse = `येथे निर्यात सल्लागारांचे संपर्क क्रमांक आहेत:\n${contactsText}\nअधिक माहितीसाठी कृपया त्यांच्याशी संपर्क साधा.`;
      } else {
        aiResponse = `Here are the contact numbers for the Export Consultancy team:\n${contactsText}\nPlease contact them for more details.`;
      }
    } else if (intent === 'equipment') {
      const contactsText = productionEquipmentContacts.map(c => `${c.name}: ${c.phone}`).join('\n');
      if (lang === 'hi') {
        aiResponse = `यह कृषि उपकरण से संबंधित रोबोटिक्स मार्ट का संपर्क नंबर है, आप उनसे संपर्क कर सकते हैं:\n${contactsText}`;
      } else if (lang === 'mr') {
        aiResponse = `हा कृषी उपकरणांशी संबंधित रोबोटिक्स मार्टचा संपर्क क्रमांक आहे, आपण त्यांच्याशी संपर्क साधू शकता:\n${contactsText}`;
      } else {
        aiResponse = `This is the Robotics Mart's contact number for agriculture related equipment, you can contact them:\n${contactsText}`;
      }
    } else if (intent === 'news') {
      // Fetch news
      const targetCategories = ['Agriculture', 'Technology', 'Business', 'Global'];
      const articles = [];
      for (const catName of targetCategories) {
        const query = `
          SELECT n.title_${lang} AS title, n.content_${lang} AS content, c.name_en AS category_name
          FROM news n
          JOIN news_categories nc ON n.id = nc.news_id
          JOIN categories c ON nc.category_id = c.id
          WHERE c.name_en ILIKE $1 AND n.is_published = true AND n.created_at >= $2::date AND n.created_at < ($2::date + INTERVAL '1 day')
          ORDER BY n.created_at DESC LIMIT 1
        `;
        const result = await pool.query(query, [`%${catName}%`, date]);
        if (result.rows.length > 0) articles.push(result.rows[0]);
      }
      aiResponse = await aiService.generateVoiceSummary(articles, lang, history);
      console.log(`[ChatController] Final news response generated.`);
    } else {
      // General Intent - Appa handles it with safety filters and context
      aiResponse = await aiService.answerGeneralQuestion(message, lang, history);
    }

    // Strip markdown formatting so Text-to-Speech reads it fluently
    if (aiResponse) {
      aiResponse = aiResponse.replace(/[*#\-_]/g, '').trim();
    }

    // 6. Save AI message
    console.log(`[ChatController] Saving AI response to database: "${aiResponse.substring(0, 50)}..."`);
    const aiMessageResult = await pool.query(
      'INSERT INTO messages (conversation_id, sender, content, intent) VALUES ($1, $2, $3, $4) RETURNING *',
      [activeConversationId, 'ai', aiResponse, intent]
    );

    console.log(`[ChatController] Sending response to client.`);

    res.json({
      success: true,
      data: {
        conversationId: activeConversationId,
        message: aiMessageResult.rows[0]
      }
    });

  } catch (error) {
    console.error('[ChatController] Error:', error);
    res.status(500).json({ success: false, message: 'Failed to process chat message' });
  }
};

const getHistory = async (req, res) => {
  try {
    const userId = req.user.id;
    const result = await pool.query(
      'SELECT id, title, updated_at FROM conversations WHERE user_id = $1 ORDER BY updated_at DESC',
      [userId]
    );
    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('[ChatController] Error fetching history:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch history' });
  }
};

const getMessages = async (req, res) => {
  try {
    const { conversationId } = req.params;
    const userId = req.user.id;
    
    // Verify ownership
    const convCheck = await pool.query('SELECT user_id FROM conversations WHERE id = $1', [conversationId]);
    if (convCheck.rows.length === 0 || convCheck.rows[0].user_id !== userId) {
      return res.status(403).json({ success: false, message: 'Unauthorized' });
    }

    const result = await pool.query(
      'SELECT * FROM messages WHERE conversation_id = $1 ORDER BY created_at ASC',
      [conversationId]
    );
    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('[ChatController] Error fetching messages:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch messages' });
  }
};

const deleteConversation = async (req, res) => {
  try {
    const { conversationId } = req.params;
    const userId = req.user.id;

    // Verify ownership
    const convCheck = await pool.query('SELECT user_id FROM conversations WHERE id = $1', [conversationId]);
    if (convCheck.rows.length === 0 || convCheck.rows[0].user_id !== userId) {
      return res.status(403).json({ success: false, message: 'Unauthorized or conversation not found' });
    }

    // Delete messages first to prevent foreign key constraint errors
    await pool.query('DELETE FROM messages WHERE conversation_id = $1', [conversationId]);
    
    // Delete the conversation
    await pool.query('DELETE FROM conversations WHERE id = $1', [conversationId]);

    res.json({ success: true, message: 'Conversation deleted successfully' });
  } catch (error) {
    console.error('[ChatController] Error deleting conversation:', error);
    res.status(500).json({ success: false, message: 'Failed to delete conversation' });
  }
};

const summarizeDay = async (req, res) => {
  try {
    const { voiceHistory = [], lang = 'en', conversationId } = req.body;
    const userId = req.user.id;

    let activeConversationId = conversationId;

    // If no conversationId, create one for the summary
    if (!activeConversationId) {
      const convResult = await pool.query(
        'INSERT INTO conversations (user_id, title) VALUES ($1, $2) RETURNING id',
        [userId, 'Daily Summary']
      );
      activeConversationId = convResult.rows[0].id;
    } else {
      // Verify ownership if conversationId provided
      const convCheck = await pool.query('SELECT user_id FROM conversations WHERE id = $1', [activeConversationId]);
      if (convCheck.rows.length === 0 || convCheck.rows[0].user_id !== userId) {
        return res.status(403).json({ success: false, message: 'Unauthorized' });
      }
    }

    // Fetch all personal chat messages for this conversation today
    const historyResult = await pool.query(
      'SELECT sender, content, created_at FROM messages WHERE conversation_id = $1 ORDER BY created_at ASC',
      [activeConversationId]
    );
    const chatHistory = historyResult.rows;

    if (chatHistory.length === 0 && voiceHistory.length === 0) {
      return res.json({ success: true, message: 'Nothing to summarize' });
    }

    console.log(`[ChatController] Generating grand summary for ${chatHistory.length} chat messages and ${voiceHistory.length} voice interactions.`);
    
    // Generate Grand Summary
    const grandSummary = await aiService.generateGrandSummary(voiceHistory, chatHistory, lang);

    // Delete all old messages
    await pool.query('DELETE FROM messages WHERE conversation_id = $1', [activeConversationId]);

    // Insert the single Grand Summary message
    const summaryResult = await pool.query(
      'INSERT INTO messages (conversation_id, sender, content, intent) VALUES ($1, $2, $3, $4) RETURNING *',
      [activeConversationId, 'ai', grandSummary, 'daily_summary']
    );

    res.json({
      success: true,
      data: {
        message: summaryResult.rows[0]
      }
    });

  } catch (error) {
    console.error('[ChatController] Error summarizing day:', error);
    res.status(500).json({ success: false, message: 'Failed to summarize day' });
  }
};

module.exports = {
  sendMessage,
  getHistory,
  getMessages,
  deleteConversation,
  summarizeDay
};
