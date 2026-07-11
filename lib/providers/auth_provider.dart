import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:http/http.dart' as http;
import '../config/pocketbase_config.dart';
import '../config/app_config.dart';
import '../models/user.dart';

class AuthState {
  final bool isAuthenticated;
  final UserModel? currentUser;
  final bool isLoading;
  final String? errorMessage;
  final bool isUsingFallback; // Selalu false karena menggunakan database nyata
  final String? registeredEmail;
  final String? registeredPassword;
  final bool hasPassword; // Menandakan apakah user punya password (false jika login via Google)

  AuthState({
    required this.isAuthenticated,
    this.currentUser,
    required this.isLoading,
    this.errorMessage,
    this.isUsingFallback = false,
    this.registeredEmail,
    this.registeredPassword,
    this.hasPassword = true, // Default true untuk user yang register biasa
  });

  AuthState copyWith({
    bool? isAuthenticated,
    UserModel? currentUser,
    bool? isLoading,
    String? errorMessage,
    bool? isUsingFallback,
    String? registeredEmail,
    String? registeredPassword,
    bool? hasPassword,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentUser: currentUser ?? this.currentUser,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isUsingFallback: isUsingFallback ?? this.isUsingFallback,
      registeredEmail: registeredEmail ?? this.registeredEmail,
      registeredPassword: registeredPassword ?? this.registeredPassword,
      hasPassword: hasPassword ?? this.hasPassword,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier()
      : super(AuthState(
          isAuthenticated: false,
          currentUser: null,
          isLoading: false,
          errorMessage: null,
          isUsingFallback: false,
        )) {
    // Muat sesi login yang tersimpan saat inisialisasi pertama kali
    loadSession();
  }

  void clearRegisteredCredentials() {
    state = AuthState(
      isAuthenticated: state.isAuthenticated,
      currentUser: state.currentUser,
      isLoading: state.isLoading,
      errorMessage: state.errorMessage,
      isUsingFallback: state.isUsingFallback,
      registeredEmail: null,
      registeredPassword: null,
    );
  }

  // Instansiasi Klien PocketBase
  final PocketBase pb = PocketBaseConfig.pb;

  Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('saved_email');
      final password = prefs.getString('saved_password');
      final hasPassword = prefs.getBool('has_password') ?? true; // Default true

      if (email != null && password != null) {
        final cachedUid = prefs.getString('saved_uid');
        final cachedName = prefs.getString('saved_name');
        final cachedPhone = prefs.getString('saved_phone');
        final cachedRole = prefs.getString('saved_role');
        final cachedAddress = prefs.getString('saved_address');
        final cachedAvatar = prefs.getString('saved_avatar') ?? '';
        final cachedPostalCode = prefs.getString('saved_postal_code') ?? '';

        if (cachedUid != null && cachedName != null && cachedPhone != null && cachedRole != null && cachedAddress != null) {
          // Masuk secara instan menggunakan cache lokal (mencegah layar login berkedip)
          state = AuthState(
            isAuthenticated: true,
            currentUser: UserModel(
              uid: cachedUid,
              name: cachedName,
              email: email,
              phone: cachedPhone,
              role: cachedRole,
              address: cachedAddress,
              avatar: cachedAvatar,
              postalCode: cachedPostalCode,
            ),
            isLoading: false,
            errorMessage: null,
            isUsingFallback: false,
            hasPassword: hasPassword,
          );
        }

        // Lakukan login senyap (silent refresh) di latar belakang untuk mencocokkan data server nyata
        await login(email, password);
      } else if (email != null && !hasPassword) {
        // User login via Google, tidak ada password tersimpan
        final cachedUid = prefs.getString('saved_uid');
        final cachedName = prefs.getString('saved_name');
        final cachedPhone = prefs.getString('saved_phone');
        final cachedRole = prefs.getString('saved_role');
        final cachedAddress = prefs.getString('saved_address');
        final cachedAvatar = prefs.getString('saved_avatar') ?? '';
        final cachedPostalCode = prefs.getString('saved_postal_code') ?? '';

        if (cachedUid != null && cachedName != null && cachedPhone != null && cachedRole != null && cachedAddress != null) {
          state = AuthState(
            isAuthenticated: true,
            currentUser: UserModel(
              uid: cachedUid,
              name: cachedName,
              email: email,
              phone: cachedPhone,
              role: cachedRole,
              address: cachedAddress,
              avatar: cachedAvatar,
              postalCode: cachedPostalCode,
            ),
            isLoading: false,
            errorMessage: null,
            isUsingFallback: false,
            hasPassword: false,
          );
        }
      }
    } catch (e) {
      // Hiraukan error pemuatan senyap
    }
  }

  Future<bool> login(String email, String password) async {
    final bool isInitialLoading = state.currentUser == null;
    if (isInitialLoading) {
      state = state.copyWith(isLoading: true, errorMessage: null, isUsingFallback: false);
    }

    try {
      // Melakukan request autentikasi ke server PocketBase
      final authData = await pb.collection('users').authWithPassword(
        email.trim().toLowerCase(),
        password,
      );

      final record = authData.record;
      if (record == null) {
        throw Exception("Kredensial valid, namun gagal mengambil profil pengguna.");
      }

      final user = UserModel(
        uid: record.id,
        name: record.getStringValue('name'),
        email: record.getStringValue('email'),
        phone: record.getStringValue('phone'),
        role: record.getStringValue('role') == 'pembeli' || record.getStringValue('role').isEmpty 
            ? 'buyer' 
            : record.getStringValue('role'),
        address: record.getStringValue('address'),
        avatar: record.getStringValue('avatar'),
        postalCode: record.getStringValue('postalCode'),
      );

      // Simpan sesi login ke penyimpanan lokal
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', email.trim().toLowerCase());
      await prefs.setString('saved_password', password);
      await prefs.setString('saved_uid', user.uid);
      await prefs.setString('saved_name', user.name);
      await prefs.setString('saved_phone', user.phone);
      await prefs.setString('saved_role', user.role);
      await prefs.setString('saved_address', user.address);
      await prefs.setString('saved_avatar', user.avatar);
      await prefs.setString('saved_postal_code', user.postalCode);
      await prefs.setBool('has_password', true); // User punya password

      state = AuthState(
        isAuthenticated: true,
        currentUser: user,
        isLoading: false,
        errorMessage: null,
        isUsingFallback: false,
        hasPassword: true, // User login dengan password
      );
      return true;
    } catch (e) {
      // Tampilkan pesan error resmi dari server PocketBase
      String msg = 'Gagal melakukan login. Periksa koneksi atau kredensial Anda.';
      if (e is ClientException) {
        final map = e.response['data'] as Map<String, dynamic>?;
        if (map != null && map.isNotEmpty) {
          final firstError = map.values.first;
          if (firstError is Map && firstError.containsKey('message')) {
            msg = firstError['message'].toString();
          } else if (firstError is String) {
            msg = firstError;
          }
        } else {
          msg = e.response['message'] ?? msg;
        }
      } else if (e.toString().contains('400')) {
        msg = 'Email atau kata sandi Anda salah.';
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
        isUsingFallback: false,
      );
      return false;
    }
  }

  Future<bool> loginWithGoogle(void Function(Uri url) launchUrlCallback) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isUsingFallback: false);

    try {
      final authData = await pb.collection('users').authWithOAuth2(
        'google',
        launchUrlCallback,
      ).timeout(const Duration(minutes: 5)); // Higher timeout for interactive web logins

      var record = authData.record;
      if (record == null) {
        throw Exception("Gagal mengambil data profil Google Anda.");
      }

      // Jika kolom role di database masih kosong (N/A), otomatis update di database ke 'pembeli'
      if (record.getStringValue('role').isEmpty) {
        try {
          record = await pb.collection('users').update(record.id, body: {
            'role': 'pembeli',
          });
        } catch (e) {
          // Abaikan jika gagal update
        }
      }

      final user = UserModel(
        uid: record.id,
        name: record.getStringValue('name').isEmpty 
            ? record.getStringValue('username') 
            : record.getStringValue('name'),
        email: record.getStringValue('email'),
        phone: record.getStringValue('phone'),
        role: record.getStringValue('role') == 'pembeli' || record.getStringValue('role').isEmpty 
            ? 'buyer' 
            : record.getStringValue('role'),
        address: record.getStringValue('address'),
        avatar: record.getStringValue('avatar'),
        postalCode: record.getStringValue('postalCode'),
      );

      // Save session locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', user.email);
      await prefs.setString('saved_uid', user.uid);
      await prefs.setString('saved_name', user.name);
      await prefs.setString('saved_phone', user.phone);
      await prefs.setString('saved_role', user.role);
      await prefs.setString('saved_address', user.address);
      await prefs.setString('saved_avatar', user.avatar);
      await prefs.setString('saved_postal_code', user.postalCode);
      await prefs.setBool('has_password', false); // User login via Google, belum punya password

      state = AuthState(
        isAuthenticated: true,
        currentUser: user,
        isLoading: false,
        errorMessage: null,
        isUsingFallback: false,
        hasPassword: false, // User login via Google, belum punya password
      );
      return true;
    } catch (e) {
      String msg = 'Gagal melakukan login Google. Periksa koneksi Anda.';
      if (e is ClientException) {
        msg = e.response['message'] ?? msg;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
        isUsingFallback: false,
      );
      return false;
    }
  }

  /// Langkah 1 registrasi: kirim OTP ke email pembeli.
  /// Backend menyimpan data user sementara dan mengirim email OTP.
  /// Akun PocketBase belum dibuat sampai OTP diverifikasi.
  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isUsingFallback: false);

    try {
      final trimmedEmail = email.trim().toLowerCase();

      // Panggil backend untuk generate & kirim OTP ke email
      final response = await http.post(
        Uri.parse('${_backendBaseUrl()}/send-register-otp'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({
          'name': name.trim(),
          'email': trimmedEmail,
          'phone': phone.trim(),
          'password': password,
          'role': role,
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        // Simpan email & password sementara untuk dipakai setelah OTP diverifikasi
        state = AuthState(
          isAuthenticated: false,
          currentUser: null,
          isLoading: false,
          errorMessage: null,
          isUsingFallback: false,
          registeredEmail: trimmedEmail,
          registeredPassword: password,
          hasPassword: true,
        );
        return true;
      } else {
        final msg = body['error'] ?? body['message'] ?? 'Gagal mengirim OTP registrasi';
        state = state.copyWith(isLoading: false, errorMessage: msg, isUsingFallback: false);
        return false;
      }
    } catch (e) {
      String msg = 'Gagal melakukan pendaftaran. Periksa koneksi Anda.';
      state = state.copyWith(isLoading: false, errorMessage: msg, isUsingFallback: false);
      return false;
    }
  }

  /// Langkah 2 registrasi: verifikasi OTP dan buat akun PocketBase.
  Future<bool> verifyRegisterOtp(String email, String otp) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await http.post(
        Uri.parse('${_backendBaseUrl()}/verify-register-otp'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({'email': email.trim().toLowerCase(), 'otp': otp.trim()}),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final password = state.registeredPassword;
        if (password != null) {
          // Lakukan login otomatis
          final loggedIn = await login(email, password);
          if (loggedIn) {
            clearRegisteredCredentials();
            return true;
          }
        }
        // Fallback jika password tidak ditemukan
        state = state.copyWith(isLoading: false, errorMessage: null);
        return true;
      } else {
        final msg = body['error'] ?? body['message'] ?? 'Kode OTP tidak valid';
        state = state.copyWith(isLoading: false, errorMessage: msg);
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal verifikasi OTP: ${e.toString()}');
      return false;
    }
  }

  /// Kirim ulang OTP registrasi tanpa perlu data user lagi (data masih di backend store).
  Future<bool> resendRegisterOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${_backendBaseUrl()}/resend-register-otp'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return true;
      } else {
        state = state.copyWith(errorMessage: body['error'] ?? 'Gagal kirim ulang OTP');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal kirim ulang OTP: ${e.toString()}');
      return false;
    }
  }

  /// Mengembalikan base URL backend (VPS atau ngrok).
  String _backendBaseUrl() {
    return AppConfig.apiBaseUrl;
  }

  Future<bool> requestPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isUsingFallback: false);
    try {
      // Generate 6-digit OTP
      final random = Random();
      final otp = (100000 + random.nextInt(900000)).toString();

      // Save OTP and timestamp to SharedPreferences for local verification
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('reset_otp', otp);
      await prefs.setString('reset_email', email.trim().toLowerCase());
      await prefs.setInt('reset_otp_timestamp', DateTime.now().millisecondsSinceEpoch);

      // Kirim OTP via backend Node.js (nodemailer)
      try {
        final response = await http.post(
          Uri.parse('${_backendBaseUrl()}/send-reset-otp'),
          headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
          body: jsonEncode({'email': email.trim().toLowerCase(), 'otp': otp}),
        );
        final respBody = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode == 200 && respBody['success'] == true) {
          print('[OTP] ✅ Reset OTP sent via backend to $email');
        } else {
          print('[OTP] ⚠️ Backend returned: ${respBody['error']}');
        }
      } catch (sendErr) {
        print('[OTP] ⚠️ Backend email failed, OTP saved locally: $otp');
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      String msg = 'Gagal mengirim email OTP. Periksa koneksi atau email Anda.';
      if (e is ClientException) {
        msg = e.response['message'] ?? msg;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
        isUsingFallback: false,
      );
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String otp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOtp = prefs.getString('reset_otp');
      final savedEmail = prefs.getString('reset_email');
      final timestamp = prefs.getInt('reset_otp_timestamp');
      
      // Check if OTP exists
      if (savedOtp == null || savedEmail == null || timestamp == null) {
        return false;
      }
      
      // Check if email matches
      if (savedEmail != email.trim().toLowerCase()) {
        return false;
      }
      
      // Check if OTP matches
      if (savedOtp != otp) {
        return false;
      }
      
      // Check if OTP is expired (5 minutes = 300000 milliseconds)
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = now - timestamp;
      if (diff > 300000) {
        // OTP expired
        await prefs.remove('reset_otp');
        await prefs.remove('reset_email');
        await prefs.remove('reset_otp_timestamp');
        return false;
      }
      
      return true;
    } catch (e) {
      print('Error verifying OTP: $e');
      return false;
    }
  }

  Future<bool> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, isUsingFallback: false);
    try {
      // Verifikasi OTP terlebih dahulu (dari SharedPreferences lokal)
      final isValidOtp = await verifyOtp(email, otp);
      if (!isValidOtp) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Kode OTP tidak valid atau sudah kadaluarsa',
          isUsingFallback: false,
        );
        return false;
      }

      // Reset password via backend Node.js (menggunakan admin PocketBase auth)
      // Sama seperti createPassword — backend login sebagai admin, tidak perlu oldPassword
      final response = await http.post(
        Uri.parse('${_backendBaseUrl()}/reset-password'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'newPassword': newPassword,
        }),
      );

      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || responseBody['success'] != true) {
        final errMsg = responseBody['error'] ?? responseBody['details'] ?? 'Gagal mereset password';
        state = state.copyWith(isLoading: false, errorMessage: errMsg, isUsingFallback: false);
        return false;
      }

      // Hapus OTP dari SharedPreferences setelah berhasil
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('reset_otp');
      await prefs.remove('reset_email');
      await prefs.remove('reset_otp_timestamp');

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      String msg = 'Gagal memperbarui kata sandi.';
      if (e is ClientException) {
        msg = e.response['message'] ?? msg;
      } else {
        msg = e.toString();
      }
      print('Reset password error: $e');
      state = state.copyWith(isLoading: false, errorMessage: msg, isUsingFallback: false);
      return false;
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String phone,
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = state.currentUser;
      if (user == null) throw Exception("Tidak ada pengguna aktif.");

      String updatedAvatar = user.avatar;

      if (PocketBaseConfig.enablePocketBase) {
        final List<http.MultipartFile> files = [];
        if (imageBytes != null && imageFilename != null) {
          files.add(http.MultipartFile.fromBytes('avatar', imageBytes, filename: imageFilename));
        }

        final record = await pb.collection('users').update(
          user.uid,
          body: {
            'name': name.trim(),
            'phone': phone.trim(),
          },
          files: files,
        );

        updatedAvatar = record.getStringValue('avatar');
      }

      final updatedUser = user.copyWith(
        name: name.trim(),
        phone: phone.trim(),
        avatar: updatedAvatar,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_name', updatedUser.name);
      await prefs.setString('saved_phone', updatedUser.phone);
      await prefs.setString('saved_avatar', updatedUser.avatar);

      state = state.copyWith(
        currentUser: updatedUser,
        isLoading: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      String msg = 'Gagal memperbarui profil.';
      if (e is ClientException) {
        msg = _parseClientException(e, msg);
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> updateAddress(String newAddress, String newPostalCode) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = state.currentUser;
      if (user == null) throw Exception("Tidak ada pengguna aktif.");

      if (PocketBaseConfig.enablePocketBase) {
        await pb.collection('users').update(user.uid, body: {
          'address': newAddress.trim(),
          'postalCode': newPostalCode.trim(),
        });
      }

      final updatedUser = user.copyWith(
        address: newAddress.trim(),
        postalCode: newPostalCode.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_address', updatedUser.address);
      await prefs.setString('saved_postal_code', updatedUser.postalCode);

      state = state.copyWith(
        currentUser: updatedUser,
        isLoading: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      String msg = 'Gagal memperbarui alamat.';
      if (e is ClientException) {
        msg = _parseClientException(e, msg);
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = state.currentUser;
      if (user == null) throw Exception("Tidak ada pengguna aktif.");

      if (PocketBaseConfig.enablePocketBase) {
        // 1. Update password
        await pb.collection('users').update(user.uid, body: {
          'oldPassword': oldPassword.trim(),
          'password': newPassword.trim(),
          'passwordConfirm': newPassword.trim(),
        });

        // 2. Re-authenticate to avoid invalidating the auth token
        await pb.collection('users').authWithPassword(
          user.email.trim().toLowerCase(),
          newPassword.trim(),
        );
      }

      // 3. Simpan kata sandi baru secara lokal
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_password', newPassword.trim());
      await prefs.setBool('has_password', true);

      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        hasPassword: true,
      );
      return true;
    } catch (e) {
      String msg = 'Gagal memperbarui kata sandi.';
      if (e is ClientException) {
        msg = _parseClientException(e, msg);
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  // Method khusus untuk membuat password pertama kali (user login via Google)
  // Memanggil backend Node.js yang authenticated sebagai admin PocketBase
  Future<bool> createPassword({
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = state.currentUser;
      if (user == null) throw Exception("Tidak ada pengguna aktif.");

      if (PocketBaseConfig.enablePocketBase) {
        // Panggil backend Node.js di localhost:3000
        // Backend sudah login sebagai admin PocketBase (pb.admins.authWithPassword)
        // sehingga bisa set password tanpa oldPassword untuk user OAuth
        final response = await http.post(
          Uri.parse('${_backendBaseUrl()}/set-first-password'),
          headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
          body: jsonEncode({
            'userId': user.uid,
            'password': newPassword.trim(),
          }),
        );

        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

        if (response.statusCode != 200 || responseBody['success'] != true) {
          final errMsg = responseBody['error'] ?? responseBody['details'] ?? 'Gagal membuat password';
          throw Exception(errMsg);
        }

        // Re-authenticate dengan password baru
        await pb.collection('users').authWithPassword(
          user.email.trim().toLowerCase(),
          newPassword.trim(),
        );
      }

      // Simpan kata sandi baru secara lokal
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_password', newPassword.trim());
      await prefs.setBool('has_password', true);

      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        hasPassword: true,
      );
      return true;
    } catch (e) {
      String msg = 'Gagal membuat kata sandi.';
      if (e is ClientException) {
        msg = _parseClientException(e, msg);
      } else {
        msg = e.toString();
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  String _parseClientException(ClientException e, String defaultMsg) {
    final data = e.response['data'] as Map<String, dynamic>?;
    if (data != null && data.isNotEmpty) {
      final buffer = StringBuffer();
      data.forEach((key, val) {
        if (val is Map && val.containsKey('message')) {
          buffer.write('${key}: ${val['message']}. ');
        } else {
          buffer.write('${key}: $val. ');
        }
      });
      return buffer.toString();
    }
    return e.response['message'] ?? defaultMsg;
  }

  Future<void> logout() async {
    pb.authStore.clear();

    // Hapus hanya data sesi login — data chat history TIDAK dihapus
    // agar history chat tetap tersimpan meski user logout
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.remove('saved_uid');
      await prefs.remove('saved_name');
      await prefs.remove('saved_phone');
      await prefs.remove('saved_role');
      await prefs.remove('saved_address');
      await prefs.remove('saved_avatar');
      await prefs.remove('saved_postal_code');
      await prefs.remove('has_password');
      await prefs.remove('reset_otp');
      await prefs.remove('reset_email');
      await prefs.remove('reset_otp_timestamp');
      // key 'chat_messages_*', 'chat_convo_*', 'chat_sessions_*' TIDAK dihapus
    } catch (e) {
      // ignore
    }

    state = AuthState(
      isAuthenticated: false,
      currentUser: null,
      isLoading: false,
      errorMessage: null,
      isUsingFallback: false,
    );
  }

  Future<bool> sendOtpViaGmailSmtp({
    required String email,
    required String otp,
    required String gmailUser,
    required String gmailAppPassword,
  }) async {
    final smtpServer = gmail(gmailUser, gmailAppPassword);

    final message = Message()
      ..from = Address(gmailUser, 'Kartara Security')
      ..recipients.add(email)
      ..subject = 'Kode OTP Pemulihan Kata Sandi - Kartara'
      ..html = '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>Verifikasi OTP Kartara</title>
        </head>
        <body style="font-family: Arial, sans-serif; background-color: #FDFBF7; padding: 20px; margin: 0;">
          <div style="max-width: 600px; margin: 0 auto; background-color: #FFFFFF; border: 1px solid #FFEBE0; border-radius: 16px; padding: 28px; box-shadow: 0 4px 12px rgba(0,0,0,0.03);">
            <h2 style="color: #F26A21; margin-top: 0;">Pemulihan Kata Sandi Kartara</h2>
            <p style="color: #4A4A4A; font-size: 14px; line-height: 1.5;">Halo,</p>
            <p style="color: #4A4A4A; font-size: 14px; line-height: 1.5;">Kami menerima permintaan pengaturan ulang kata sandi Anda. Gunakan kode verifikasi OTP di bawah ini untuk melanjutkan:</p>
            
            <div style="background-color: #FFF5EE; border: 1px solid #FFD8C2; border-radius: 12px; padding: 16px; text-align: center; margin: 24px 0;">
              <span style="font-size: 32px; font-weight: bold; color: #F26A21; letter-spacing: 6px; font-family: monospace;">$otp</span>
            </div>
            
            <p style="color: #4A4A4A; font-size: 14px; line-height: 1.5;">Kode verifikasi OTP ini bersifat rahasia dan hanya berlaku selama 15 menit. Mohon jangan sebarkan kode ini kepada siapapun.</p>
            <p style="color: #7C7C7C; font-size: 13px; line-height: 1.5; margin-top: 24px;">Terima kasih,<br><strong>Tim Dukungan Kartara</strong></p>
          </div>
        </body>
        </html>
      ''';

    try {
      await send(message, smtpServer);
      return true;
    } catch (e) {
      print('Gagal mengirim email SMTP: $e');
      return false;
    }
  }

  Future<bool> sendOtpViaPocketBaseHook({
    required String email,
    required String otp,
  }) async {
    try {
      await pb.send(
        '/api/send-otp',
        method: 'POST',
        body: {
          'email': email,
          'otp': otp,
        },
      );
      return true;
    } catch (e) {
      String details = e.toString();
      if (e is ClientException) {
        details = e.response['error'] ?? e.response['message'] ?? e.toString();
      }
      print('Gagal mengirim email OTP via PocketBase hook: $details');
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
