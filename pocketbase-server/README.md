# PocketBase Server untuk Kartara - Railway Deployment

## Deploy ke Railway (Step-by-step)

### Langkah 1: Buat Proyek Railway Baru
1. Login ke [Railway.app](https://railway.app).
2. Klik **"New Project"** → **"Deploy from GitHub repo"**.
3. Hubungkan ke repository GitHub proyek Kartara Anda.
4. Pilih folder **`pocketbase-server/`** sebagai root direktori (di pengaturan Railway).

### Langkah 2: Tambahkan Volume Penyimpanan Persisten
1. Di dalam dashboard Railway proyek PocketBase, klik tab **"Volumes"**.
2. Klik **"Add Volume"**.
3. Atur **Mount Path** ke: `/pb/pb_data`
4. Klik **"Save"**. Data SQLite PocketBase Anda kini akan tersimpan permanen.

### Langkah 3: Dapatkan URL Online PocketBase
1. Buka tab **"Settings"** → bagian **"Networking"**.
2. Klik **"Generate Domain"**.
3. Anda akan mendapatkan URL seperti: `https://pocketbase-kartara.up.railway.app`
4. **Simpan URL ini**, nanti akan dimasukkan ke kode Flutter dan backend Node.js.

### Langkah 4: Setup Admin PocketBase Online
1. Buka `https://URL-POCKETBASE-RAILWAY-ANDA/_/` di browser.
2. Buat akun admin baru (email & password).
3. Import skema koleksi dari PocketBase lokal Anda.

---

## Versi PocketBase yang Digunakan
Pastikan versi di `Dockerfile` (ARG `PB_VERSION`) sama dengan versi PocketBase lokal Anda.
Versi saat ini: **v0.23.4**
