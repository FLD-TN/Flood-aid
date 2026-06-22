const crypto = require('crypto');

const ENCRYPT_KEY = process.env.PHONE_ENCRYPT_KEY;

function encryptPhone(phone) {
  if (!ENCRYPT_KEY || !phone) return null;
  const key = Buffer.from(ENCRYPT_KEY, 'hex');
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  let encrypted = cipher.update(phone, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const authTag = cipher.getAuthTag().toString('hex');
  return iv.toString('hex') + ':' + encrypted + ':' + authTag;
}

function decryptPhone(encryptedStr) {
  if (!ENCRYPT_KEY || !encryptedStr) return null;
  try {
    const key = Buffer.from(ENCRYPT_KEY, 'hex');
    const parts = encryptedStr.split(':');
    const iv = Buffer.from(parts[0], 'hex');
    const encrypted = parts[1];
    const authTag = Buffer.from(parts[2], 'hex');
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(authTag);
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch {
    return null;
  }
}

module.exports = { encryptPhone, decryptPhone };
