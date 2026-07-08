require('dotenv').config();
const { initializeDatabase, pool } = require('./config/db');
const Notification = require('./models/Notification');
const notificationService = require('./services/notificationService');

async function testSilentPing() {
  console.log('🔄 Initializing database connection...');
  await initializeDatabase();
  
  console.log('🔍 Fetching all active device tokens...');
  const tokens = await Notification.getAllTokens();
  
  if (!tokens || tokens.length === 0) {
    console.log('❌ No active tokens found in the database.');
    process.exit(0);
  }
  
  console.log(`🚀 Sending Silent Ping to ${tokens.length} devices...`);
  
  try {
    const result = await notificationService.sendSilentPingToTokens(tokens);
    console.log('\n✅ --- SILENT PING RESULTS --- ✅');
    console.log(`🎯 Successfully Reached: ${result.successCount} devices`);
    console.log(`🗑️ Uninstalled / Failed: ${result.failureCount} devices`);
    console.log('-------------------------------\n');
    console.log('Updating database... (waiting 3 seconds)');
    await new Promise(resolve => setTimeout(resolve, 3000));
    console.log('Done! Check your admin dashboard now.');
  } catch (err) {
    console.error('Error sending silent ping:', err);
  }
  
  process.exit(0);
}

testSilentPing();
