import 'package:pocketbase/pocketbase.dart';

class PocketBaseConfig {
  // ── URL PocketBase ────────────────────────────────────────────────────────
  // ✅ ONLINE (Railway) — aktif
  static const String baseUrl = 'https://kartara-production-97ca.up.railway.app';

  // 🔧 LOKAL (Development) — uncomment jika testing lokal
  // static const String baseUrl = 'http://127.0.0.1:8090';

  // Jika true, aplikasi akan mencoba menggunakan PocketBase. Jika false, akan langsung menggunakan mode offline demo.
  static const bool enablePocketBase = true;

  // Mengaktifkan fallback otomatis ke mode offline/demo apabila koneksi server PocketBase gagal/timeout
  static const bool enableAutoOfflineFallback = true;

  // Klien PocketBase global tunggal agar status autentikasi sinkron di seluruh aplikasi
  static final PocketBase pb = PocketBase(baseUrl);

  static Future<void> logActivity({
    required String title,
    required String icon,
    required String admin,
  }) async {
    if (!enablePocketBase) return;
    try {
      await pb.collection('activity_logs').create(body: {
        'title': title,
        'icon': icon,
        'admin': admin,
      });
    } catch (e) {
      print('Error logging activity: $e');
    }
  }
}
