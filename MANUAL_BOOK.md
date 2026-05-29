# 📖 Panduan Manual & Dokumentasi Teknis Aplikasi Kartara
> **Kartara** — Platform E-Commerce UMKM Modern untuk Penjualan Kerupuk & Kuliner Khas, dilengkapi dengan Integrasi Payment Gateway Midtrans, Sistem Logistik Biteship, Database PocketBase, dan Asisten AI Pintar.

---

## 🛠️ Daftar Isi
1. [Pengenalan Aplikasi](#-pengenalan-aplikasi)
2. [Arsitektur Sistem](#-arsitektur-sistem)
3. [Fitur-Fitur Utama (Sisi Pembeli)](#-fitur-fitur-utama-sisi-pembeli)
4. [Fitur-Fitur Utama (Sisi Admin)](#-fitur-fitur-utama-sisi-admin)
5. [Panduan Instalasi & Konfigurasi](#-panduan-instalasi--konfigurasi)
6. [Panduan Menjalankan Aplikasi](#-panduan-menjalankan-aplikasi)
7. [Struktur Kode & Folder](#-struktur-kode--folder)
8. [Troubleshooting & Solusi](#-troubleshooting--solusi)

---

## 🌟 Pengenalan Aplikasi

**Kartara** adalah sebuah platform digital e-commerce terintegrasi yang dirancang khusus untuk memajukan UMKM lokal (seperti industri kerupuk khas Jepara). Aplikasi ini menghadirkan pengalaman berbelanja tingkat premium dengan performa tinggi yang dibangun menggunakan **Flutter** pada sisi frontend, **Express.js (Node.js)** pada sisi backend, dan **PocketBase** sebagai sistem database real-time dan manajemen pengguna.

Aplikasi ini tidak hanya menyajikan antarmuka visual yang modern dan premium (*glassmorphism*, skema warna hangat HSL, mikro-animasi), tetapi juga dilengkapi dengan sistem transaksi yang sepenuhnya terotomatisasi menggunakan **Midtrans**, pelacakan pengiriman kurir real-time menggunakan **Biteship**, serta asisten chatbot berbasis kecerdasan buatan (**Gemini AI**).

---

## 🏗️ Arsitektur Sistem

Kartara menggunakan arsitektur modern berbasis microservices & real-time synchronization:

```
┌─────────────────────────────────────────────────────────┐
│                    KARTARA FRONTEND                     │
│               (Flutter App / Riverpod)                  │
└───────────────────┬─────────────────┬───────────────────┘
                    │                 │
     REST API / WebSockets       REST API / Webhooks
                    │                 │
┌───────────────────▼───┐         ┌───▼───────────────────┐
│       POCKETBASE      │         │    KARTARA BACKEND    │
│  (Database, Auth,    │         │  (Node.js / Express)  │
│   Real-Time Sync)     │         └───┬─────────┬─────────┘
└───────────────────────┘             │         │
                                  Midtrans   Biteship
                                     API       API
                                      │         │
                              ┌───────▼─┐ ┌─────▼───┐
                              │Midtrans │ │Biteship │
                              │ Gateway │ │Logistik │
                              └─────────┘ └─────────┘
```

### Komponen Utama:
1. **Frontend (Flutter)**: Mengelola UI/UX, manajemen state menggunakan Riverpod, pemetaan lokasi pembeli, serta interaksi tracking kurir.
2. **Backend (Node.js/Express)**: Bertindak sebagai gateway pembayaran aman untuk berinteraksi dengan API Midtrans (membuat token pembayaran Snap & menerima webhook transaksi) serta kalkulasi ongkos kirim resmi dari Biteship.
3. **Database & Auth (PocketBase)**: Mengelola penyimpanan data produk, data transaksi, data pengguna terdaftar, serta sinkronisasi status pesanan secara real-time.

---

## 📱 Fitur-Fitur Utama (Sisi Pembeli)

### 1. Sistem Autentikasi Ganda (Auth)
* **Pendaftaran & Login Biasa**: Pengguna dapat mendaftar menggunakan nama, email, nomor telepon, alamat, dan kata sandi dengan verifikasi form lengkap.
* **Google OAuth 2.0**: Memungkinkan pengguna masuk secara instan menggunakan Akun Google dengan tombol sekali klik.
* **Reset Password & OTP**: Sistem pemulihan sandi secara mandiri menggunakan kode OTP 6-digit yang dikirimkan ke email terdaftar.

### 2. Beranda & Katalog Produk Premium
* **Kategori Filter Interaktif**: Memudahkan pembeli menyaring produk berdasarkan kategori (misal: Kerupuk Mentah, Kerupuk Matang, Cemilan).
* **Fitur Pencarian Visual**: Pencarian super cepat langsung dari header dengan pencocokan nama produk secara dinamis.
* **Promo Banner & Kupon Belanja**: Banner dinamis interaktif yang menampilkan diskon aktif untuk memikat minat pembeli.

### 3. Keranjang & Sistem Checkout Real-Time
* **Smart Cart**: Pengguna dapat menambah, mengurangi, atau menghapus item langsung dari keranjang belanja dengan kalkulasi total harga otomatis.
* **Kalkulasi Ongkir Real-Time (Biteship)**: Pada layar Checkout, sistem secara otomatis meminta tarif ongkir ke API Biteship berdasarkan berat produk dan kode pos pembeli. Dilengkapi fallback simulasi cerdas jika API Biteship sedang offline.
* **Informasi Kurir Pilihan**: Integrasi pilihan kurir terpercaya seperti JNE, J&T, Sicepat, dan POS Indonesia.

### 4. Integrasi Pembayaran Midtrans Snap
* Ketika pembeli menekan tombol **"Buat Pesanan & Bayar"**, backend akan membuat token transaksi resmi dari Midtrans Sandbox.
* Pembeli diarahkan ke **Midtrans Snap Page** di dalam aplikasi untuk melakukan pembayaran menggunakan berbagai metode: *Virtual Account (Mandiri, BCA, BNI, BRI), e-Wallet (Gopay, ShopeePay), Alfamart/Indomaret, atau Kartu Kredit*.
* Setelah pembayaran lunas, status pesanan otomatis ter-update menjadi **"Paid (Sudah Dibayar)"** secara real-time melalui webhook backend.

### 5. Live Tracking Map (Pelacakan Kurir Real-Time)
* Peta interaktif lengkap dengan penanda lokasi toko (UMKM), lokasi pembeli, serta ikon kurir yang bergerak dinamis.
* Memberikan kepuasan visual kepada pembeli untuk memantau perjalanan kerupuk pesanan mereka sampai ke depan rumah.

---

## 💼 Fitur-Fitur Utama (Sisi Admin)

Layar Admin dapat diakses dengan masuk menggunakan akun yang memiliki hak akses administrator (`role: 'admin'`).

### 1. Dashboard Ringkasan Bisnis (Dashboard Screen)
* **Ringkasan Pendapatan**: Total pendapatan bersih dari seluruh transaksi berstatus lunas (`Paid` / `Processing` / `Shipped` / `Completed`).
* **Total Penjualan**: Jumlah produk yang berhasil terjual.
* **Total Pelanggan Terdaftar**: Angka total pembeli terdaftar di platform Kartara yang ditarik real-time dari database.

### 2. Manajemen Produk (CRUD Screen)
* **Tambah Produk Baru**: Form modern dengan input Nama Produk, Deskripsi, Kategori, Harga, Stok, Berat (Gram), dan URL Gambar Produk.
* **Edit & Hapus Produk**: Memungkinkan perubahan informasi produk secara instan yang langsung terlihat di sisi pembeli.

### 3. Manajemen Pesanan Real-Time (Order Management)
* **Pencarian & Filter Status**: Admin dapat mencari ID transaksi atau nama pembeli, serta memfilternya berdasarkan kategori status (`Pending`, `Diproses Matang/Mentah`, `Dikirim`, `Selesai`, `Dibatalkan`).
* **Draggable Bottom Sheet (Bebas Overflow)**: Antarmuka pembaruan status pesanan premium yang dapat di-drag dan di-scroll dengan mulus di berbagai ukuran resolusi layar.

### 4. Pengaturan & Profil Admin Persisten
* **Profil Admin**: Perubahan Nama Lengkap dan Nomor Telepon tersimpan dan diperbarui secara nyata ke PocketBase.
* **Ubah Password**: Sistem penggantian kata sandi admin yang aman dan terenkripsi.
* **Pengaturan Operasional Toko (Persisten SharedPreferences)**: Admin dapat mengatur nama toko, alamat operasional, status buka/tutup toko, serta mengaktifkan/menonaktifkan jenis kurir logistik. Pengaturan ini tersimpan secara permanen di memori lokal perangkat.
* **Audit Trail (Log Aktivitas)**: Menampilkan catatan log riwayat tindakan yang dilakukan oleh administrator untuk keamanan pelacakan aktivitas toko.

---

## ⚙️ Panduan Instalasi & Konfigurasi

### 1. Kebutuhan Perangkat Lunak (Prerequisites)
Sebelum memulai instalasi, pastikan komputer Anda telah terpasang:
* **Flutter SDK** (Versi 3.19.0 atau yang lebih baru)
* **Dart SDK**
* **Node.js** (Versi 18 atau yang lebih baru) & **NPM**
* **PocketBase** (Versi 0.23+ untuk autentikasi superuser)

---

### 2. Konfigurasi Backend & Payment Gateway

1. Buka direktori backend:
   ```bash
   cd d:/Project/kartara/backend
   ```
2. Salin atau buat file `.env` untuk mengatur API Key Anda:
   ```env
   PORT=3000
   POCKETBASE_URL=http://localhost:8090
   POCKETBASE_ADMIN_EMAIL=admin@kartara.id
   POCKETBASE_ADMIN_PASSWORD=adminpassword
   MIDTRANS_SERVER_KEY=SB-Mid-server-XXXXXX
   MIDTRANS_CLIENT_KEY=SB-Mid-client-XXXXXX
   BITESHIP_API_KEY=biteship_test_XXXXXX
   GEMINI_API_KEY=AIzaSyXXXXXX
   ```
3. Pasang semua dependensi backend:
   ```bash
   npm install
   ```

---

### 3. Konfigurasi Database PocketBase

1. Unduh PocketBase dan jalankan di localhost komputer Anda:
   ```bash
   ./pocketbase serve --http="127.0.0.1:8090"
   ```
2. Buka Dashboard Admin PocketBase di browser: `http://localhost:8090/_/`
3. Buat akun Administrator pertama kali dengan email `admin@kartara.id` dan kata sandi pilihan Anda (sesuaikan dengan `.env` backend).
4. Pastikan koleksi (`Collections`) berikut telah terbuat di PocketBase:
   * **`users`**: Tambahkan kolom custom seperti `role` (text), `phone` (text), `address` (text), `avatar` (text).
   * **`products`**: Kolom `name` (text), `description` (text), `price` (number), `stock` (number), `weight` (number), `imageUrl` (text), `category` (text).
   * **`orders`**: Kolom `id` (text), `recipientName` (text), `totalInvoice` (number), `status` (text), `items` (json), `shippingAddress` (text), `paymentToken` (text), `paymentUrl` (text).

---

### 4. Konfigurasi Frontend (Flutter)

1. Buka file konfigurasi PocketBase di Flutter: `lib/config/pocketbase_config.dart`
2. Pastikan alamat URL mengarah ke server backend dan PocketBase yang tepat:
   ```dart
   class PocketBaseConfig {
     static const String baseUrl = 'http://10.0.2.2:8090'; // Gunakan IP 10.0.2.2 untuk emulator Android
     // Atau gunakan http://localhost:8090 jika menggunakan emulator web/desktop
     static const bool enablePocketBase = true;
   }
   ```
3. Unduh semua paket dependensi Flutter:
   ```bash
   flutter pub get
   ```

---

## 🚀 Panduan Menjalankan Aplikasi

Jalankan seluruh sistem dengan langkah-langkah berurutan di bawah ini untuk memastikan sinkronisasi pembayaran dan database berjalan mulus:

### Langkah 1: Jalankan Database PocketBase
Buka terminal baru, navigasikan ke lokasi biner PocketBase Anda berada, lalu jalankan:
```bash
./pocketbase serve --http="127.0.0.1:8090"
```

### Langkah 2: Jalankan Node.js Backend Gateway
Buka terminal baru di folder backend:
```bash
cd d:/Project/kartara/backend
npm run start
```
*Anda akan melihat log koneksi sukses:* `🚀 Kartara Payment Gateway Backend running on port 3000` & `✅ PocketBase admin authenticated`.

### Langkah 3: Ekspos Port Backend Menggunakan Ngrok (Untuk Webhook Pembayaran)
Agar server Midtrans Sandbox di internet dapat mengirimkan notifikasi pembayaran lunas ke backend lokal Anda, Anda harus mengekspos port `3000` menggunakan Ngrok:
```bash
ngrok http 3000
```
Salin URL forwarding https yang diberikan oleh Ngrok (misal: `https://abcd-123.ngrok-free.app`), lalu daftarkan URL tersebut di **Dashboard Midtrans Sandbox > Settings > Notification URL** dengan format:
`https://abcd-123.ngrok-free.app/api/webhook`

### Langkah 4: Jalankan Aplikasi Flutter
Buka terminal baru di folder proyek Flutter utama (`d:/Project/kartara`):
```bash
flutter run
```
Pilih perangkat emulator target Anda (Chrome, Edge, Android Emulator, atau Windows Desktop).

---

## 📂 Struktur Kode & Folder

Berikut adalah struktur folder utama dari proyek Kartara Flutter:

```
lib/
│
├── config/
│   └── pocketbase_config.dart     # Konfigurasi alamat server PB & fallback database
│
├── models/
│   ├── order.dart                 # Model representasi data Transaksi
│   ├── product.dart               # Model representasi data Produk kerupuk
│   └── user.dart                  # Model representasi data Akun Pengguna
│
├── providers/
│   ├── app_state.dart             # Riverpod Notifier untuk manajemen produk & pesanan
│   └── auth_provider.dart         # Riverpod Notifier untuk autentikasi user & sinkronisasi sesi
│
├── screens/
│   ├── auth/                      # Layar Login, Register, & Reset Password OTP
│   │
│   ├── buyer/                     # Layar untuk pembeli
│   │   ├── home_screen.dart       # Katalog utama, pencarian, & filter produk
│   │   ├── cart_screen.dart       # Keranjang belanja & perubahan kuantitas
│   │   ├── checkout_screen.dart   # Input alamat, kalkulasi ongkir Biteship, & tombol bayar
│   │   └── tracking_map_screen.dart # Peta pelacakan real-time perjalanan kurir
│   │
│   └── admin/                     # Layar untuk Administrator UMKM
│       ├── dashboard_screen.dart  # Metrik omset penjualan & navigasi cepat admin
│       ├── product_list_screen.dart # Tabel/grid daftar produk milik UMKM
│       ├── product_form_screen.dart # Formulir tambah & ubah detail produk (CRUD)
│       ├── transaction_list_screen.dart # Pelacakan order, filter status, & drag-sheet status
│       └── profile_screen.dart    # Ubah profil, ganti password, & persistent toko lokal
│
└── widgets/                       # Kumpulan widget reusable UI (card, dialog, nav bar)
```

---

## 🔍 Troubleshooting & Solusi

### 1. Error: RenderFlex overflowed by X pixels
* **Penyebab**: Konten visual melebihi ruang vertikal/horizontal yang tersedia di layar beresolusi rendah (sering terjadi di emulator web berukuran kecil).
* **Solusi**: Bungkus widget Column yang meluap menggunakan `SingleChildScrollView` atau ganti dengan `ListView` dengan physics bouncing scroll. (Masalah ini telah sepenuhnya diperbaiki pada layar bottom-sheet transaksi admin).

### 2. Transaksi Midtrans Berhasil Dibayar, tapi Status Pesanan di Aplikasi Tidak Berubah
* **Penyebab**: Server Midtrans tidak dapat mengirimkan notifikasi ke localhost Anda, atau token ngrok Anda sudah mati/kadaluarsa.
* **Solusi**: Jalankan kembali `ngrok http 3000`, salin URL forwarding baru, dan perbarui Notification URL di Dashboard Sandbox Midtrans. Pastikan juga server backend Node.js Anda dalam keadaan aktif.

### 3. API Biteship Mengembalikan Error 400 (Bad Request)
* **Penyebab**: Kode pos asal/tujuan atau berat produk tidak valid (misal: berat bernilai 0 gram).
* **Solusi**: Sistem kami sudah mendeteksi error ini dan akan secara otomatis beralih (*fallback*) ke metode kalkulasi simulasi logistik cerdas, sehingga transaksi di checkout tetap berjalan lancar tanpa hambatan bagi pembeli.

---

> **💡 Tips Tambahan:** Selalu jalankan `flutter analyze` secara berkala sebelum melakukan kompilasi rilis produksi untuk memastikan seluruh sintaks kode terbebas dari kesalahan penulisan dan peringatan usang.

---
*Manual Book ini disusun sebagai pedoman resmi operasional dan pengembangan berkelanjutan bagi pengembang dan administrator sistem aplikasi Kartara.*
