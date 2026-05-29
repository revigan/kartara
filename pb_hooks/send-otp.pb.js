/**
 * PocketBase Hook untuk mengirim OTP via email
 * Endpoint: POST /api/send-otp
 * Body: { email: string, otp: string }
 */

routerAdd("POST", "/api/send-otp", (c) => {
  try {
    const data = $apis.requestInfo(c).data;
    const email = data.email;
    const otp = data.otp;

    if (!email || !otp) {
      return c.json(400, { 
        "error": "Email dan OTP harus diisi" 
      });
    }

    // Kirim email dengan OTP
    const message = new MailerMessage({
      from: {
        address: $app.settings().meta.senderAddress,
        name: $app.settings().meta.senderName,
      },
      to: [{ address: email }],
      subject: "Kode OTP Reset Password - Kartara",
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Kode OTP Reset Password</title>
        </head>
        <body style="font-family: Arial, sans-serif; background-color: #F5F1ED; padding: 20px; margin: 0;">
          <div style="max-width: 600px; margin: 0 auto; background-color: #FFFFFF; border: 1px solid #FFEBE0; border-radius: 16px; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.03);">
            
            <!-- Header -->
            <div style="text-align: center; margin-bottom: 32px;">
              <div style="width: 80px; height: 80px; background-color: #FFF5EE; border-radius: 50%; margin: 0 auto 16px; display: flex; align-items: center; justify-content: center;">
                <span style="font-size: 40px;">🛒</span>
              </div>
              <h1 style="color: #C0430E; margin: 0; font-size: 32px; font-weight: bold;">Kartara</h1>
            </div>

            <!-- Title -->
            <h2 style="color: #2C2C2C; margin: 0 0 16px 0; font-size: 24px; font-weight: bold;">Reset Kata Sandi</h2>
            
            <!-- Description -->
            <p style="color: #6B5E52; font-size: 15px; line-height: 1.6; margin: 0 0 24px 0;">
              Kami menerima permintaan untuk mengatur ulang kata sandi akun Anda. Gunakan kode OTP di bawah ini untuk melanjutkan proses reset password.
            </p>
            
            <!-- OTP Box -->
            <div style="background-color: #FFF5EE; border: 2px solid #C0430E; border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0;">
              <p style="color: #6B5E52; font-size: 14px; margin: 0 0 12px 0; font-weight: 600;">KODE OTP ANDA</p>
              <p style="font-size: 40px; font-weight: bold; color: #C0430E; letter-spacing: 8px; margin: 0; font-family: 'Courier New', monospace;">${otp}</p>
            </div>
            
            <!-- Warning -->
            <div style="background-color: #FFF5EE; border-left: 4px solid #C0430E; padding: 16px; margin: 24px 0; border-radius: 4px;">
              <p style="color: #2C2C2C; font-size: 14px; margin: 0 0 8px 0; font-weight: bold;">⚠️ Penting:</p>
              <ul style="color: #6B5E52; font-size: 13px; margin: 0; padding-left: 20px; line-height: 1.6;">
                <li>Kode OTP ini berlaku selama <strong>5 menit</strong></li>
                <li>Jangan bagikan kode ini kepada siapapun</li>
                <li>Tim Kartara tidak akan pernah meminta kode OTP Anda</li>
              </ul>
            </div>
            
            <!-- Footer -->
            <div style="margin-top: 32px; padding-top: 24px; border-top: 1px solid #E0D5C7;">
              <p style="color: #9E9E9E; font-size: 13px; line-height: 1.6; margin: 0;">
                Jika Anda tidak meminta reset password, abaikan email ini. Akun Anda tetap aman.
              </p>
              <p style="color: #6B5E52; font-size: 14px; margin: 16px 0 0 0;">
                Salam,<br>
                <strong style="color: #C0430E;">Tim Kartara</strong>
              </p>
            </div>
            
          </div>
          
          <!-- Footer Text -->
          <div style="text-align: center; margin-top: 24px;">
            <p style="color: #9E9E9E; font-size: 12px; margin: 0;">
              Email ini dikirim secara otomatis, mohon tidak membalas email ini.
            </p>
          </div>
        </body>
        </html>
      `,
    });

    $app.newMailClient().send(message);

    return c.json(200, { 
      "success": true,
      "message": "OTP berhasil dikirim ke email" 
    });

  } catch (error) {
    console.error("Error sending OTP:", error);
    return c.json(500, { 
      "error": "Gagal mengirim OTP: " + error.message 
    });
  }
});
