require('dotenv').config();
const { pool } = require('./config/db');

async function checkDevices() {
  const result = await pool.query('SELECT device_name, app_status, notification_status, fcm_token, uninstall_detected_at, last_notification_status FROM user_devices');
  console.log(JSON.stringify(result.rows, null, 2));
  process.exit(0);
}
checkDevices();
