const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16;
const SALT_LENGTH = 16;
const TAG_LENGTH = 16;

const SECRETS_DIR = path.join(__dirname, '..', 'security', 'admin_devices');

// Ensure directory exists
if (!fs.existsSync(SECRETS_DIR)) {
  fs.mkdirSync(SECRETS_DIR, { recursive: true });
}

function getKey() {
  const key = process.env.ADMIN_DEVICE_ENCRYPTION_KEY;
  if (!key) {
    throw new Error('ADMIN_DEVICE_ENCRYPTION_KEY is not defined in environment variables');
  }
  // Ensure the key is exactly 32 bytes for AES-256
  return crypto.createHash('sha256').update(key).digest();
}

/**
 * Encrypts data using AES-256-GCM
 */
function encryptData(data) {
  const key = getKey();
  const iv = crypto.randomBytes(IV_LENGTH);
  const salt = crypto.randomBytes(SALT_LENGTH);

  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  
  let encrypted = cipher.update(JSON.stringify(data), 'utf8', 'hex');
  encrypted += cipher.final('hex');
  
  const authTag = cipher.getAuthTag().toString('hex');

  // Format: iv:salt:authTag:encryptedData
  return `${iv.toString('hex')}:${salt.toString('hex')}:${authTag}:${encrypted}`;
}

/**
 * Decrypts AES-256-GCM data
 */
function decryptData(encryptedString) {
  try {
    const parts = encryptedString.split(':');
    if (parts.length !== 4) return null;

    const [ivHex, saltHex, authTagHex, encryptedHex] = parts;
    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');
    const key = getKey();

    const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(authTag);

    let decrypted = decipher.update(encryptedHex, 'hex', 'utf8');
    decrypted += decipher.final('utf8');

    return JSON.parse(decrypted);
  } catch (error) {
    console.error('[AdminDeviceManager] Decryption failed:', error.message);
    return null;
  }
}

class AdminDeviceManager {
  static getSlotPath(slotNumber) {
    return path.join(SECRETS_DIR, `slot_${slotNumber}.enc`);
  }

  static async getAllSlots() {
    const slots = [];
    for (let i = 1; i <= 5; i++) {
      const filePath = this.getSlotPath(i);
      let slotData = null;
      if (fs.existsSync(filePath)) {
        const encryptedContent = fs.readFileSync(filePath, 'utf8');
        slotData = decryptData(encryptedContent);
      }
      slots.push({ slot: i, data: slotData });
    }
    return slots;
  }

  static async verifyAdminDevice(fingerprint) {
    // If no fingerprint is provided, block
    if (!fingerprint) return false;

    for (let i = 1; i <= 5; i++) {
      const filePath = this.getSlotPath(i);
      if (fs.existsSync(filePath)) {
        const encryptedContent = fs.readFileSync(filePath, 'utf8');
        const slotData = decryptData(encryptedContent);
        if (slotData && slotData.hardwareFingerprint === fingerprint) {
          return true;
        }
      }
    }
    return false; // No slot matched
  }

  static async updateSlot(slotNumber, deviceData) {
    if (slotNumber < 1 || slotNumber > 5) {
      throw new Error('Invalid slot number. Must be between 1 and 5.');
    }

    const payload = {
      version: 1, // Future-proofing
      hardwareFingerprint: deviceData.hardwareFingerprint,
      deviceName: deviceData.deviceName || 'Unknown Device',
      manufacturer: deviceData.manufacturer || 'Unknown',
      model: deviceData.model || 'Unknown',
      platform: deviceData.platform || 'Unknown',
      osVersion: deviceData.osVersion || 'Unknown',
      appVersion: deviceData.appVersion || 'Unknown',
      registeredAt: new Date().toISOString(),
      lastUpdatedAt: new Date().toISOString()
    };

    const encryptedString = encryptData(payload);
    const filePath = this.getSlotPath(slotNumber);
    fs.writeFileSync(filePath, encryptedString, 'utf8');

    return payload;
  }

  /**
   * Returns the total number of populated hardware slots.
   * Useful for detecting a brand new server that needs zero-to-one bootstrapping.
   */
  static async getFilledSlotCount() {
    let count = 0;
    for (let i = 1; i <= 5; i++) {
      const filePath = this.getSlotPath(i);
      if (fs.existsSync(filePath)) {
        count++;
      }
    }
    return count;
  }
}

module.exports = AdminDeviceManager;
