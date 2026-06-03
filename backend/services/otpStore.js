/**
 * Persistent OTP Store menggunakan file JSON.
 * Data OTP bertahan meskipun server di-restart oleh nodemon.
 *
 * Format file: { [email]: { otp, expiresAt, userData } }
 */

const fs = require('fs');
const path = require('path');

const STORE_FILE = path.join(__dirname, '..', '.otp_store.json');
const OTP_TTL_MS = 5 * 60 * 1000; // 5 menit

// ─── Helpers ────────────────────────────────────────────────────────────────

function _readStore() {
  try {
    if (!fs.existsSync(STORE_FILE)) return {};
    const raw = fs.readFileSync(STORE_FILE, 'utf8');
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

function _writeStore(data) {
  try {
    fs.writeFileSync(STORE_FILE, JSON.stringify(data, null, 2), 'utf8');
  } catch (e) {
    console.error('[OTP-STORE] ❌ Gagal menulis file store:', e.message);
  }
}

function _purgeExpired(store) {
  const now = Date.now();
  let changed = false;
  for (const email of Object.keys(store)) {
    if (store[email].expiresAt < now) {
      delete store[email];
      changed = true;
    }
  }
  return changed;
}

// ─── Public API ─────────────────────────────────────────────────────────────

/**
 * Simpan OTP + data user ke store.
 */
function saveOtp(email, { otp, userData }) {
  const store = _readStore();
  _purgeExpired(store);
  store[email] = {
    otp,
    expiresAt: Date.now() + OTP_TTL_MS,
    userData,
    createdAt: Date.now(),
  };
  _writeStore(store);
}

/**
 * Ambil entry OTP. Return null jika tidak ada atau sudah expired.
 */
function getOtp(email) {
  const store = _readStore();
  const entry = store[email];
  if (!entry) return null;
  if (entry.expiresAt < Date.now()) {
    // Hapus yang expired
    delete store[email];
    _writeStore(store);
    return null;
  }
  return entry;
}

/**
 * Hapus OTP setelah berhasil diverifikasi.
 */
function deleteOtp(email) {
  const store = _readStore();
  if (store[email]) {
    delete store[email];
    _writeStore(store);
  }
}

/**
 * Update OTP dengan kode baru (untuk resend), userData tetap sama.
 * Return null jika sesi sudah tidak ada (harus daftar ulang).
 */
function refreshOtp(email, newOtp) {
  const store = _readStore();
  const entry = store[email];
  if (!entry) return null;
  store[email] = {
    ...entry,
    otp: newOtp,
    expiresAt: Date.now() + OTP_TTL_MS,
  };
  _writeStore(store);
  return store[email];
}

module.exports = { saveOtp, getOtp, deleteOtp, refreshOtp };
