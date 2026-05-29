const express = require('express');
const router = express.Router();
const axios = require('axios');

const POCKETBASE_URL = process.env.POCKETBASE_URL || 'http://127.0.0.1:8090';
const ADMIN_EMAIL = process.env.POCKETBASE_ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.POCKETBASE_ADMIN_PASSWORD;

/**
 * Authenticate sebagai PocketBase admin/superuser.
 * Mendukung PocketBase v0.22 (admins) DAN v0.23+ (_superusers).
 * Mengembalikan admin token.
 */
async function getAdminToken() {
  // Coba PocketBase v0.23+ terlebih dahulu (_superusers collection)
  try {
    const resp = await axios.post(
      `${POCKETBASE_URL}/api/collections/_superusers/auth-with-password`,
      { identity: ADMIN_EMAIL, password: ADMIN_PASSWORD },
      { headers: { 'Content-Type': 'application/json' } }
    );
    console.log('✅ Admin auth via _superusers (PB v0.23+)');
    return resp.data.token;
  } catch (e1) {
    // Fallback ke PocketBase v0.22 dan lebih lama (admins endpoint)
    try {
      const resp = await axios.post(
        `${POCKETBASE_URL}/api/admins/auth-with-password`,
        { identity: ADMIN_EMAIL, password: ADMIN_PASSWORD },
        { headers: { 'Content-Type': 'application/json' } }
      );
      console.log('✅ Admin auth via admins (PB v0.22)');
      return resp.data.token;
    } catch (e2) {
      const msg =
        e2.response?.data?.message ||
        e2.response?.data?.error ||
        e2.message ||
        'Unknown error';
      throw new Error(`Admin auth failed: ${msg}`);
    }
  }
}

/**
 * POST /api/set-first-password
 * Set password untuk user yang login via OAuth (Google) pertama kali.
 * Body: { userId, password }
 */
router.post('/set-first-password', async (req, res) => {
  try {
    const { userId, password } = req.body;

    if (!userId || !password) {
      return res.status(400).json({ error: 'userId dan password harus diisi' });
    }
    if (password.length < 8) {
      return res.status(400).json({ error: 'Password minimal 8 karakter' });
    }

    console.log(`[SET-PASSWORD] Setting password for user: ${userId}`);

    // Dapatkan admin token (kompatibel dengan semua versi PocketBase)
    let token;
    try {
      token = await getAdminToken();
    } catch (e) {
      console.error('[SET-PASSWORD] ❌ Admin auth failed:', e.message);
      return res.status(500).json({
        error: 'Gagal autentikasi admin PocketBase',
        details: e.message,
        hint: 'Pastikan POCKETBASE_ADMIN_EMAIL dan POCKETBASE_ADMIN_PASSWORD di .env sudah benar',
      });
    }

    // Update password user menggunakan admin token via REST API langsung
    try {
      await axios.patch(
        `${POCKETBASE_URL}/api/collections/users/records/${userId}`,
        { password: password, passwordConfirm: password },
        {
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
        }
      );

      console.log('[SET-PASSWORD] ✅ Password set for user:', userId);
      return res.json({ success: true, message: 'Password berhasil dibuat' });
    } catch (updateError) {
      const errData = updateError.response?.data;
      console.error('[SET-PASSWORD] ❌ Update error:', errData || updateError.message);
      return res.status(500).json({
        error: 'Gagal update password',
        details: errData?.message || errData || updateError.message,
      });
    }
  } catch (error) {
    console.error('[SET-PASSWORD] ❌ Final error:', error);
    res.status(500).json({ error: 'Gagal membuat password', details: error.message });
  }
});

/**
 * POST /api/reset-password
 * Reset password user (lupa password) - tidak perlu oldPassword.
 * Body: { email, newPassword }
 */
router.post('/reset-password', async (req, res) => {
  try {
    const { email, newPassword } = req.body;

    if (!email || !newPassword) {
      return res.status(400).json({ error: 'Email dan newPassword harus diisi' });
    }
    if (newPassword.length < 8) {
      return res.status(400).json({ error: 'Password minimal 8 karakter' });
    }

    console.log(`[RESET-PASSWORD] Resetting password for: ${email}`);

    // Dapatkan admin token
    let token;
    try {
      token = await getAdminToken();
      console.log('[RESET-PASSWORD] ✅ Admin authenticated');
    } catch (e) {
      console.error('[RESET-PASSWORD] ❌ Admin auth failed:', e.message);
      return res.status(500).json({
        error: 'Gagal autentikasi admin PocketBase',
        hint: 'Pastikan POCKETBASE_ADMIN_EMAIL dan POCKETBASE_ADMIN_PASSWORD di .env benar',
      });
    }

    // Cari user berdasarkan email via REST API
    let records;
    try {
      const response = await axios.get(
        `${POCKETBASE_URL}/api/collections/users/records`,
        {
          params: {
            filter: `email="${email.trim().toLowerCase()}"`,
            perPage: 1,
          },
          headers: { Authorization: `Bearer ${token}` },
        }
      );
      records = response.data.items;
    } catch (findError) {
      console.error('[RESET-PASSWORD] ❌ Find error:', findError.response?.data || findError.message);
      return res.status(500).json({ error: 'Gagal mencari user: ' + findError.message });
    }

    if (!records || records.length === 0) {
      return res.status(404).json({ error: 'Email tidak ditemukan dalam sistem' });
    }

    const userId = records[0].id;
    console.log(`[RESET-PASSWORD] Found user ID: ${userId}`);

    // Update password dengan admin token
    try {
      await axios.patch(
        `${POCKETBASE_URL}/api/collections/users/records/${userId}`,
        { password: newPassword, passwordConfirm: newPassword },
        {
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
        }
      );

      console.log('[RESET-PASSWORD] ✅ Password reset for user:', userId);
      return res.json({ success: true, message: 'Password berhasil direset' });
    } catch (updateError) {
      const errData = updateError.response?.data;
      console.error('[RESET-PASSWORD] ❌ Update error:', errData || updateError.message);
      return res.status(500).json({
        error: 'Gagal update password',
        details: errData?.message || errData || updateError.message,
      });
    }
  } catch (error) {
    console.error('[RESET-PASSWORD] ❌ Final error:', error);
    res.status(500).json({ error: 'Gagal mereset password', details: error.message });
  }
});

module.exports = router;
