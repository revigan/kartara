const nodemailer = require('nodemailer');

/**
 * Membuat transporter nodemailer dengan Gmail SMTP.
 * Gunakan Gmail App Password, bukan password biasa.
 * Setup: https://myaccount.google.com/apppasswords
 */
function createTransporter() {
  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
}

/**
 * Template HTML email OTP yang cantik dan branded.
 */
function buildOtpEmailHtml({ otp, purpose = 'register' }) {
  const purposeLabel =
    purpose === 'register'
      ? 'verifikasi akun baru'
      : 'pemulihan kata sandi';

  const headline =
    purpose === 'register'
      ? '🎉 Selamat Datang di Kartara!'
      : '🔐 Pemulihan Kata Sandi';

  const bodyText =
    purpose === 'register'
      ? 'Terima kasih telah mendaftar di Kartara! Gunakan kode OTP berikut untuk memverifikasi alamat email Anda dan menyelesaikan pendaftaran:'
      : 'Kami menerima permintaan pengaturan ulang kata sandi akun Anda. Gunakan kode OTP berikut untuk melanjutkan:';

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kode OTP Kartara</title>
</head>
<body style="margin:0;padding:0;background-color:#F5F1ED;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#F5F1ED;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background-color:#FFFFFF;border-radius:20px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.07);">
          
          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#C0430E 0%,#E05A20 100%);padding:32px 40px;text-align:center;">
              <div style="width:60px;height:60px;background:rgba(255,255,255,0.15);border-radius:16px;display:inline-flex;align-items:center;justify-content:center;margin-bottom:16px;">
                <span style="font-size:28px;">🛒</span>
              </div>
              <h1 style="margin:0;color:#FFFFFF;font-size:26px;font-weight:700;letter-spacing:-0.5px;">Kartara</h1>
              <p style="margin:8px 0 0;color:rgba(255,255,255,0.85);font-size:14px;">${headline}</p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:36px 40px;">
              <p style="margin:0 0 8px;color:#6B5E52;font-size:13px;text-transform:uppercase;letter-spacing:1px;font-weight:600;">Kode ${purposeLabel.toUpperCase()}</p>
              <p style="margin:0 0 24px;color:#2C2C2C;font-size:15px;line-height:1.6;">${bodyText}</p>

              <!-- OTP Box -->
              <div style="background:linear-gradient(135deg,#FFF5EE 0%,#FFF0E6 100%);border:2px solid #FFD8C2;border-radius:16px;padding:28px;text-align:center;margin-bottom:24px;">
                <p style="margin:0 0 8px;color:#C0430E;font-size:12px;font-weight:600;letter-spacing:2px;text-transform:uppercase;">Kode Verifikasi Anda</p>
                <span style="font-size:42px;font-weight:800;color:#C0430E;letter-spacing:10px;font-family:'Courier New',monospace;">${otp}</span>
              </div>

              <!-- Info rows -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
                <tr>
                  <td style="padding:10px 0;border-bottom:1px solid #F5F1ED;">
                    <span style="color:#9E9E9E;font-size:13px;">⏱ Berlaku selama</span>
                    <span style="color:#2C2C2C;font-size:13px;font-weight:600;float:right;">5 menit</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:10px 0;">
                    <span style="color:#9E9E9E;font-size:13px;">🔒 Digunakan untuk</span>
                    <span style="color:#2C2C2C;font-size:13px;font-weight:600;float:right;">${purposeLabel}</span>
                  </td>
                </tr>
              </table>

              <!-- Warning -->
              <div style="background:#FFF9F0;border-left:4px solid #F59E0B;border-radius:8px;padding:14px 16px;margin-bottom:24px;">
                <p style="margin:0;color:#92400E;font-size:13px;line-height:1.5;">
                  ⚠️ <strong>Jaga kerahasiaan kode ini.</strong> Tim Kartara tidak pernah meminta kode OTP Anda. Jika bukan Anda yang melakukan ini, abaikan email ini.
                </p>
              </div>

              <p style="margin:0;color:#9E9E9E;font-size:13px;line-height:1.5;">
                Butuh bantuan? Hubungi kami di <a href="mailto:support@kartara.id" style="color:#C0430E;text-decoration:none;">support@kartara.id</a>
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#F5F1ED;padding:20px 40px;text-align:center;border-top:1px solid #EDE8E3;">
              <p style="margin:0;color:#B0A599;font-size:12px;">© 2025 Kartara. Semua hak dilindungi.</p>
              <p style="margin:4px 0 0;color:#B0A599;font-size:12px;">Email ini dikirim secara otomatis, harap tidak membalas.</p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `.trim();
}

/**
 * Kirim email OTP ke user.
 * @param {Object} options
 * @param {string} options.to      - Alamat email tujuan
 * @param {string} options.otp     - 6-digit OTP
 * @param {'register'|'reset'} options.purpose - Tujuan pengiriman OTP
 * @returns {{ sent: boolean, devMode: boolean }}
 */
async function sendOtpEmail({ to, otp, purpose = 'register' }) {
  const isConfigured =
    process.env.SMTP_USER &&
    process.env.SMTP_PASS &&
    process.env.SMTP_USER !== 'your-email@gmail.com' &&
    process.env.SMTP_PASS !== 'your-gmail-app-password';

  // ── DEV MODE: SMTP belum dikonfigurasi ──────────────────────────────────────
  if (!isConfigured) {
    console.log('\n' + '='.repeat(60));
    console.log('📧 [DEV MODE] SMTP belum dikonfigurasi di .env');
    console.log(`   To      : ${to}`);
    console.log(`   OTP     : ${otp}   ← Gunakan kode ini untuk testing`);
    console.log(`   Purpose : ${purpose}`);
    console.log('='.repeat(60) + '\n');
    return { sent: false, devMode: true };
  }

  // ── PRODUCTION MODE: Kirim via Gmail SMTP ──────────────────────────────────
  const transporter = createTransporter();

  const subjectMap = {
    register: '✉️ Kode Verifikasi Akun Kartara Anda',
    reset: '🔐 Kode OTP Pemulihan Kata Sandi - Kartara',
  };

  const info = await transporter.sendMail({
    from: `"Kartara" <${process.env.SMTP_USER}>`,
    to,
    subject: subjectMap[purpose] || subjectMap.register,
    html: buildOtpEmailHtml({ otp, purpose }),
  });

  console.log(`[EMAIL] ✅ OTP email sent to ${to} | MessageId: ${info.messageId}`);
  return { sent: true, devMode: false };
}

module.exports = { sendOtpEmail };
