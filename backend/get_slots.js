require('dotenv').config();
const { initializeDatabase, pool } = require('./config/db');
const AdminDeviceManager = require('./utils/adminDeviceManager');

async function main() {
  try {
    await initializeDatabase();
    const slots = await AdminDeviceManager.getAllSlots();
    console.log("=== VALID HARDWARE FINGERPRINTS ===");
    slots.forEach(s => {
      if (s.data && s.data.hardwareFingerprint) {
        console.log(`Slot ${s.slot}: ${s.data.hardwareFingerprint}`);
      }
    });
    console.log("===================================");
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

main();
