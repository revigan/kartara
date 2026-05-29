/**
 * PocketBase Hook untuk reset password dengan OTP
 * Endpoint: POST /api/reset-password
 * Body: { email: string, newPassword: string }
 */

routerAdd("POST", "/api/reset-password", (c) => {
  try {
    const data = $apis.requestInfo(c).data;
    const email = data.email;
    const newPassword = data.newPassword;

    if (!email || !newPassword) {
      return c.json(400, { 
        "error": "Email dan password baru harus diisi" 
      });
    }

    // Validate password length
    if (newPassword.length < 8) {
      return c.json(400, { 
        "error": "Password minimal 8 karakter" 
      });
    }

    // Find user by email with better error handling
    let record;
    try {
      record = $app.dao().findFirstRecordByFilter(
        "users",
        "email = {:email}",
        { email: email.toLowerCase().trim() }
      );
    } catch (findError) {
      console.error("Error finding user:", findError);
      return c.json(404, { 
        "error": "Email tidak ditemukan dalam sistem" 
      });
    }

    if (!record) {
      return c.json(404, { 
        "error": "Email tidak ditemukan dalam sistem" 
      });
    }

    // Update password with better error handling
    try {
      record.setPassword(newPassword);
      $app.dao().saveRecord(record);
      
      console.log("Password updated successfully for user:", email);
      
      return c.json(200, { 
        "success": true,
        "message": "Password berhasil diperbarui" 
      });
    } catch (saveError) {
      console.error("Error saving password:", saveError);
      return c.json(500, { 
        "error": "Gagal menyimpan password baru: " + saveError.message 
      });
    }

  } catch (error) {
    console.error("Error resetting password:", error);
    return c.json(500, { 
      "error": "Gagal memperbarui password: " + error.message 
    });
  }
});
