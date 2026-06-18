# 🦐 Kartara - E-Commerce Kerupuk Khas Jepara

Kartara adalah platform e-commerce modern yang dirancang khusus untuk memajukan UMKM pembuat kerupuk khas Jepara. Aplikasi ini dilengkapi dengan **Asisten AI Cerdas** untuk membantu pembeli mencari produk berdasarkan preferensi harga & karakteristik (renyah, gurih, pedas, dll.), serta integrasi gerbang pembayaran (Midtrans) dan pelacakan kurir real-time.

---

## 🏗️ Arsitektur Sistem

Aplikasi Kartara dibangun menggunakan tumpukan teknologi berikut:
- **Frontend**: Flutter (Dart) untuk aplikasi Android, iOS, dan Web.
- **Backend API**: Node.js + Express untuk menangani webhook pembayaran Midtrans, kalkulasi pengiriman, dan pemrosesan AI Gemini.
- **Database & Auth**: PocketBase (wrapper SQLite) untuk manajemen data real-time, autentikasi user, dan penyimpanan media/gambar.
- **AI Engine**: Google Gemini API untuk asisten virtual interaktif pembeli.

---

## 🛠️ Langkah-Langkah Menjalankan Aplikasi

Ikuti panduan berikut untuk menjalankan seluruh ekosistem Kartara di lokal Anda:

### Prasyarat (Prerequisites)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versi terbaru)
- [Node.js](https://nodejs.org/) (v16 ke atas)
- [PocketBase executable](https://pocketbase.io/docs/)

---

### Bagian 1: Setup Database (PocketBase & SQLite)

1. Jalankan server **PocketBase** Anda di lokal pada port default (`8090`):
   ```bash
   ./pocketbase serve --http="127.0.0.1:8090"
   ```
2. Buka Dashboard Admin PocketBase di browser:
   [http://127.0.0.1:8090/_/](http://127.0.0.1:8090/_/)
3. Buat akun Admin utama Anda jika pertama kali menjalankan.
4. Pastikan koleksi berikut telah terbuat dan memiliki kolom yang sesuai:
   - `products` (memiliki kolom `characteristics` berupa Array/JSON atau Text dipisah koma, `price`, `stock`, `rating`, dll.)
   - `banners` (untuk promo aktif)
   - `orders` (untuk transaksi dan status pengiriman)

---

### Bagian 2: Setup Backend (Node.js API Server)

1. Masuk ke direktori backend:
   ```bash
   cd backend
   ```
2. Install semua library pendukung:
   ```bash
   npm install
   ```
3. Buat file `.env` dengan menyalin file contoh:
   ```bash
   cp .env.example .env
   ```
4. Buka `.env` dan konfigurasikan key-key penting Anda:
   ```env
   PORT=3000

   # Database & Auth
   POCKETBASE_URL=http://127.0.0.1:8090
   POCKETBASE_ADMIN_EMAIL=admin@kartara.com
   POCKETBASE_ADMIN_PASSWORD=password-admin-anda

   # AI Integration
   GEMINI_API_KEY=AIzaSy...your-gemini-api-key-here

   # Payment Gateway (Midtrans)
   MIDTRANS_SERVER_KEY=SB-Mid-server-...
   MIDTRANS_CLIENT_KEY=SB-Mid-client-...
   MIDTRANS_IS_PRODUCTION=false
   ```
5. Jalankan server backend dalam mode development (nodemon):
   ```bash
   npm run dev
   ```
   Server backend kini berjalan di [http://localhost:3000](http://localhost:3000).

---

### Bagian 3: Setup Frontend (Flutter App)

1. Kembali ke direktori root project:
   ```bash
   cd ..
   ```
2. Ambil seluruh package dependencies Flutter:
   ```bash
   flutter pub get
   ```
3. Jalankan aplikasi di emulator Android, iOS, atau Browser pilihan Anda:
   ```bash
   # Melihat daftar device aktif
   flutter devices

   # Menjalankan aplikasi (ganti nomor dengan device target Anda)
   flutter run
   ```

---

## 💡 Cara Menguji Fitur Asisten AI Kartara

Setelah backend (port `3000`), PocketBase (port `8090`), dan Flutter berjalan:
1. Masuk ke halaman **Asisten** di aplikasi Flutter.
2. Anda bisa mengirimkan pesan teks bebas seperti:
   - 🦐 *"Rekomendasikan kerupuk tengiri yang renyah"*
   - 💰 *"Cari kerupuk di bawah harga Rp 20.000"*
   - 📦 *"Tolong lacak status pesanan terakhir saya"*
   - 💬 *"Ada yang lebih murah dari produk tadi?"* (Menguji kecerdasan follow-up percakapan)

---

## 📁 Struktur Folder Project

```text
kartara/
├── backend/                  # Server Node.js Express & Gemini Service
│   ├── config/               # Inisialisasi Midtrans & PocketBase
│   ├── controllers/          # Kontroler Chat & Transaksi
│   ├── routes/               # API endpoint router (Payment, Chat, dll)
│   ├── services/             # Integrasi Gemini AI & PocketBase SDK
│   └── server.js             # Entrypoint backend Express
├── lib/                      # Source code Flutter Frontend
├── assets/                   # Gambar, ikon, dan file statis aplikasi
├── pb_data/                  # Folder database SQLite lokal dari PocketBase
└── README.md                 # Dokumentasi panduan ini
```
