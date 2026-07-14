/// Konfigurasi URL terpusat untuk aplikasi Kartara.
/// Ubah [_mode] untuk beralih antara mode lokal dan online.
class AppConfig {
  // ── MODE SWITCH ───────────────────────────────────────────────────────────
  // ✅ production = pakai Railway | local = pakai ngrok
  static const String _mode = 'production';

  // ── URL Backend PRODUKSI (Railway) ────────────────────────────────────────
  static const String _railwayUrl =
      'https://kartara-production.up.railway.app';

  // ── URL Backend LOKAL (Ngrok untuk development) ───────────────────────────
  /// 🔧 URL ngrok aktif (ganti setiap kali ngrok di-restart)
  static const String _ngrokUrl =
      'https://surfboard-hardcopy-context.ngrok-free.dev';

  // ── URL Aktif (dipilih otomatis berdasarkan _mode) ────────────────────────
  static String get baseUrl =>
      _mode == 'production' ? _railwayUrl : _ngrokUrl;

  static String get apiBaseUrl => '$baseUrl/api';
  // ── HTTP Headers ──────────────────────────────────────────────────────────
  static const Map<String, String> defaultHeaders = {
    'ngrok-skip-browser-warning': 'true',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── Timeouts ──────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  // ── Polling ───────────────────────────────────────────────────────────────
  static const Duration courierPollingInterval = Duration(seconds: 5);

  // ── Warna Utama ───────────────────────────────────────────────────────────
  static const int primaryColorValue = 0xFFC0430E;
  static const int backgroundColorValue = 0xFFFAF7F2;
}
