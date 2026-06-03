/// Konfigurasi URL terpusat untuk aplikasi Kartara.
/// Ganti [ngrokUrl] dengan URL ngrok Anda yang aktif.
class AppConfig {
  // ── URL Backend ──────────────────────────────────────────────────────────
  /// URL ngrok aktif (ganti setiap kali ngrok di-restart)
  static const String ngrokUrl =
      'https://surfboard-hardcopy-context.ngrok-free.dev';

  /// Gunakan ini untuk Android Emulator (localhost backend)
  // static const String _localUrl = 'http://10.0.2.2:3000';

  /// Gunakan ini untuk iOS Simulator / Desktop / Web
  // static const String _localUrl = 'http://localhost:3000';

  static const String apiBaseUrl = '$ngrokUrl/api';
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
