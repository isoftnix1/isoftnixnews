require('dotenv').config();
const { pool } = require('./config/db');
const { sendNotificationToTokens } = require('./services/notificationService');

async function runTest() {
  console.log('Fetching active device tokens...');
  try {
    const result = await pool.query('SELECT fcm_token FROM user_devices WHERE fcm_token IS NOT NULL');
    const tokens = result.rows.map(row => row.fcm_token);
    
    if (tokens.length === 0) {
      console.log('No active devices found! (Please open the app on your phone so it registers a token)');
      process.exit(0);
    }
    
    console.log(`Found ${tokens.length} tokens. Sending test notification...`);
    
    const title = 'Test Square Thumbnail';
    const body = 'This is a test notification to verify that the large news image appears correctly on the right side and expands into a large picture when clicked.';
    // A demo cloudinary URL to test the 800x400 crop logic
    const testImageUrl = 'https://res.cloudinary.com/demo/image/upload/v1312461204/sample.jpg';
    
    const response = await sendNotificationToTokens(tokens, title, body, { newsId: 'test_123' }, testImageUrl);
    
    console.log('Notification sent successfully:', response);
  } catch (err) {
    console.error("Test failed:", err);
  } finally {
    pool.end();
  }
}

runTest();
