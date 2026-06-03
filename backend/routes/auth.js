const express = require('express');
const router = express.Router();
const axios = require('axios');
const crypto = require('crypto');
const { sendOtpEmail } = require('../services/emailService');
const { saveOtp, getOtp, deleteOtp, refreshOtp } = require('../services/otpStore');

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

/**
 * POST /api/send-register-otp
 * Kirim OTP ke email pembeli yang ingin mendaftar.
 * Data user disimpan sementara di memory; akun PocketBase dibuat hanya setelah OTP diverifikasi.
 * Body: { name, email, phone, password, role }
 */
router.post('/send-register-otp', async (req, res) => {
  try {
    const { name, email, phone, password, role } = req.body;

    if (!name || !email || !phone || !password) {
      return res.status(400).json({ error: 'Semua field wajib diisi (name, email, phone, password)' });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // Cek apakah email sudah terdaftar di PocketBase
    let adminToken;
    try {
      adminToken = await getAdminToken();
    } catch (e) {
      return res.status(500).json({ error: 'Gagal autentikasi admin', details: e.message });
    }

    try {
      const checkResp = await axios.get(`${POCKETBASE_URL}/api/collections/users/records`, {
        params: { filter: `email="${normalizedEmail}"`, perPage: 1 },
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      if (checkResp.data.items && checkResp.data.items.length > 0) {
        return res.status(409).json({ error: 'Email sudah terdaftar. Silakan gunakan email lain atau masuk.' });
      }
    } catch (checkErr) {
      console.error('[REGISTER-OTP] ❌ Check email error:', checkErr.response?.data || checkErr.message);
    }

    // Generate 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // Simpan ke persistent file store (survive server restart)
    saveOtp(normalizedEmail, {
      otp,
      userData: { name: name.trim(), email: normalizedEmail, phone: phone.trim(), password, role: role || 'buyer' },
    });

    console.log(`[REGISTER-OTP] 📧 Sending OTP to ${normalizedEmail} | OTP: ${otp}`);

    // Kirim email OTP (tidak akan throw jika SMTP belum dikonfigurasi)
    const emailResult = await sendOtpEmail({ to: normalizedEmail, otp, purpose: 'register' });

    const message = emailResult.devMode
      ? `[DEV] OTP untuk testing: ${otp} (cek console backend)`
      : `Kode OTP telah dikirim ke ${normalizedEmail}`;

    return res.json({
      success: true,
      message,
      devMode: emailResult.devMode,
    });
  } catch (error) {
    console.error('[REGISTER-OTP] ❌ Error:', error.message);
    res.status(500).json({ error: 'Gagal mengirim OTP', details: error.message });
  }
});

/**
 * POST /api/resend-register-otp
 * Kirim ulang OTP registrasi (user masih di halaman verifikasi).
 * Data user tetap diambil dari in-memory store yang sudah ada.
 * Body: { email }
 */
router.post('/resend-register-otp', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Email wajib diisi' });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // Generate OTP baru dan update di persistent store
    const newOtp = Math.floor(100000 + Math.random() * 900000).toString();
    const updated = refreshOtp(normalizedEmail, newOtp);

    if (!updated) {
      return res.status(400).json({
        error: 'Sesi pendaftaran tidak ditemukan. Silakan mulai ulang pendaftaran.',
      });
    }

    console.log(`[RESEND-OTP] 📧 Resending OTP to ${normalizedEmail} | OTP: ${newOtp}`);

    const emailResult = await sendOtpEmail({ to: normalizedEmail, otp: newOtp, purpose: 'register' });

    return res.json({
      success: true,
      message: emailResult.devMode
        ? `[DEV] OTP baru: ${newOtp} (cek console backend)`
        : `Kode OTP baru telah dikirim ke ${normalizedEmail}`,
      devMode: emailResult.devMode,
    });
  } catch (error) {
    console.error('[RESEND-OTP] ❌ Error:', error.message);
    res.status(500).json({ error: 'Gagal mengirim ulang OTP', details: error.message });
  }
});

/**
 * POST /api/verify-register-otp
 * Verifikasi OTP registrasi dan buat akun PocketBase jika OTP valid.
 * Body: { email, otp }
 */
router.post('/verify-register-otp', async (req, res) => {
  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({ error: 'Email dan OTP wajib diisi' });
    }

    const normalizedEmail = email.trim().toLowerCase();

    // Ambil dari persistent store
    const stored = getOtp(normalizedEmail);
    console.log(`[VERIFY-OTP] Email: ${normalizedEmail} | Stored OTP: ${stored?.otp} | Incoming: ${otp.trim()}`);

    if (!stored) {
      return res.status(400).json({ error: 'OTP tidak ditemukan atau sudah kadaluarsa. Silakan minta kode baru.' });
    }

    if (stored.otp !== otp.trim()) {
      return res.status(400).json({ error: 'Kode OTP tidak valid. Periksa kembali kode yang dikirim ke email Anda.' });
    }

    // OTP valid – buat akun di PocketBase
    const { name, phone, password, role } = stored.userData;

    let adminToken;
    try {
      adminToken = await getAdminToken();
    } catch (e) {
      return res.status(500).json({ error: 'Gagal autentikasi admin', details: e.message });
    }

    const randomString = Date.now().toString().substring(8);
    const cleanName = name.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
    const username = `${cleanName.substring(0, 8)}_${randomString}`;

    try {
      await axios.post(
        `${POCKETBASE_URL}/api/collections/users/records`,
        {
          username,
          email: normalizedEmail,
          emailVisibility: true,
          password,
          passwordConfirm: password,
          name,
          phone,
          role: role === 'buyer' ? 'pembeli' : role,
          address: '',
          avatar: '',
        },
        {
          headers: {
            Authorization: `Bearer ${adminToken}`,
            'Content-Type': 'application/json',
          },
        }
      );

      // Hapus OTP dari persistent store setelah sukses
      deleteOtp(normalizedEmail);

      console.log(`[REGISTER-OTP] ✅ Account created for: ${normalizedEmail}`);
      return res.json({ success: true, message: 'Akun berhasil dibuat! Silakan masuk.' });
    } catch (createError) {
      const errData = createError.response?.data;
      console.error('[REGISTER-OTP] ❌ Create user error:', errData || createError.message);

      let errorMsg = 'Gagal membuat akun';
      if (errData?.data) {
        const firstField = Object.keys(errData.data)[0];
        errorMsg = errData.data[firstField]?.message || errorMsg;
      } else if (errData?.message) {
        errorMsg = errData.message;
      }

      return res.status(500).json({ error: errorMsg, details: errData });
    }
  } catch (error) {
    console.error('[REGISTER-OTP] ❌ Final error:', error.message);
    res.status(500).json({ error: 'Gagal verifikasi OTP', details: error.message });
  }
});

/**
 * POST /api/send-reset-otp
 * Kirim OTP via email untuk reset password.
 * Body: { email }
 */
router.post('/send-reset-otp', async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) {
      return res.status(400).json({ error: 'Email dan OTP wajib diisi' });
    }

    await sendOtpEmail({ to: email.trim().toLowerCase(), otp, purpose: 'reset' });
    return res.json({ success: true, message: 'OTP berhasil dikirim' });
  } catch (error) {
    console.error('[SEND-RESET-OTP] ❌ Error:', error.message);
    res.status(500).json({ error: 'Gagal mengirim OTP', details: error.message });
  }
});

module.exports = router;
