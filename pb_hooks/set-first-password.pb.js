/**
 * PocketBase Hook untuk set password pertama kali (user login via Google OAuth)
 * Endpoint: POST /api/set-first-password
 * Body: { userId: string, password: string }
 * 
 * Hook ini berjalan di server PocketBase dengan akses admin penuh,
 * sehingga bisa update password tanpa perlu oldPassword.
 */

routerAdd("POST", "/api/set-first-password", (c) => {
  try {
    const data = $apis.requestInfo(c).data;
    const userId = data.userId;
    const password = data.password;

    if (!userId || !password) {
      return c.json(400, {
        "error": "userId dan password harus diisi"
      });
    }

    if (password.length < 8) {
      return c.json(400, {
        "error": "Password minimal 8 karakter"
      });
    }

    // Cari user by ID
    let record;
    try {
      record = $app.dao().findRecordById("users", userId);
    } catch (findError) {
      console.error("[SET-FIRST-PASSWORD] User not found:", findError);
      return c.json(404, {
        "error": "User tidak ditemukan"
      });
    }

    if (!record) {
      return c.json(404, {
        "error": "User tidak ditemukan"
      });
    }

    // Set password baru (admin bisa lakukan ini tanpa oldPassword)
    try {
      record.setPassword(password);
      $app.dao().saveRecord(record);

      console.log("[SET-FIRST-PASSWORD] ✅ Password set successfully for userId:", userId);

      return c.json(200, {
        "success": true,
        "message": "Password berhasil dibuat"
      });
    } catch (saveError) {
      console.error("[SET-FIRST-PASSWORD] ❌ Error saving password:", saveError);
      return c.json(500, {
        "error": "Gagal menyimpan password: " + saveError.message
      });
    }

  } catch (error) {
    console.error("[SET-FIRST-PASSWORD] ❌ Error:", error);
    return c.json(500, {
      "error": "Gagal membuat password: " + error.message
    });
  }
});
