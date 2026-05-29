// PocketBase Hook untuk set password pertama kali tanpa oldPassword
// File ini harus diletakkan di folder pb_hooks/ di direktori PocketBase

onRecordBeforeUpdateRequest((e) => {
  // Hanya untuk collection users
  if (e.collection.name !== 'users') {
    return;
  }

  const data = e.requestData;
  
  // Jika ada password baru tapi tidak ada oldPassword
  // Dan user belum punya password (OAuth user)
  if (data.password && !data.oldPassword) {
    const record = e.record;
    
    // Cek apakah user ini memang belum punya password
    // User OAuth biasanya tidak punya passwordHash
    if (!record.passwordHash || record.passwordHash === '') {
      // Bypass validasi oldPassword dengan set ke empty string
      data.oldPassword = '';
      console.log(`Allowing first password set for user: ${record.id}`);
    }
  }
}, 'users');
