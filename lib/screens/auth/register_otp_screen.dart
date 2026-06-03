import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

/// Halaman verifikasi OTP yang dikirim saat registrasi.
/// Setelah OTP valid, akun PocketBase dibuat dan user diarahkan ke login.
class RegisterOtpScreen extends ConsumerStatefulWidget {
  final String email;
  final VoidCallback onNavigateToLogin;

  const RegisterOtpScreen({
    required this.email,
    required this.onNavigateToLogin,
    super.key,
  });

  @override
  ConsumerState<RegisterOtpScreen> createState() => _RegisterOtpScreenState();
}

class _RegisterOtpScreenState extends ConsumerState<RegisterOtpScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _isResending = false;
  int _remainingSeconds = 300; // 5 menit
  Timer? _timer;

  late AnimationController _shakeController;
  late AnimationController _successController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _successAnimation;

  @override
  void initState() {
    super.initState();
    _startTimer();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
    // Set nilai awal ke 1 agar icon langsung terlihat
    _successController.value = 1.0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    _successController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _clearOtp() {
    for (var c in _otpControllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    setState(() {});
  }

  Future<void> _handleResend() async {
    if (_isResending) return;
    setState(() {
      _isResending = true;
      _remainingSeconds = 300;
    });
    _startTimer();

    // Gunakan endpoint resend yang khusus (tidak perlu data user lagi)
    final success = await ref.read(authProvider.notifier).resendRegisterOtp(widget.email);

    setState(() => _isResending = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Kode OTP baru telah dikirim ke ${widget.email}'
                : '❌ Gagal mengirim ulang OTP. Coba lagi.',
          ),
          backgroundColor:
              success ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _handleVerify() async {
    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      _shakeController.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Masukkan 6 digit kode OTP'),
          backgroundColor: const Color(0xFFE57373),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success =
        await ref.read(authProvider.notifier).verifyRegisterOtp(widget.email, otp);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      // Animasi sukses: scale dari 1 ke 1.2 lalu kembali
      await _successController.animateTo(1.2,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      await _successController.animateTo(1.0,
          duration: const Duration(milliseconds: 150), curve: Curves.easeIn);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Pendaftaran berhasil! Selamat datang di Kartara.'),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(); // Tutup OTP Screen, root screen otomatis render dashboard
      }
    } else {
      _shakeController.forward(from: 0);
      _clearOtp();
      final errorMsg = ref.read(authProvider).errorMessage ?? 'Kode OTP tidak valid atau sudah kadaluarsa';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: const Color(0xFFE57373),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _remainingSeconds == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F1ED),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFFC0430E), size: 20),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Icon email
                    ScaleTransition(
                      scale: _successAnimation,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFC0430E), Color(0xFFE05A20)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC0430E).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mark_email_read_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Kartara',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFC0430E),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),

                    const Text(
                      'Verifikasi Email',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                    const SizedBox(height: 12),

                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B5E52),
                          height: 1.6,
                        ),
                        children: [
                          const TextSpan(text: 'Kami telah mengirim kode 6 digit ke\n'),
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C2C2C),
                            ),
                          ),
                          const TextSpan(
                              text: '\nMasukkan kode untuk menyelesaikan pendaftaran.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // OTP input dengan animasi shake
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          return _OtpBox(
                            controller: _otpControllers[index],
                            focusNode: _focusNodes[index],
                            onChanged: (value) {
                              setState(() {});
                              if (value.isNotEmpty && index < 5) {
                                _focusNodes[index + 1].requestFocus();
                              } else if (value.isEmpty && index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }
                              // Auto-verify when all filled
                              if (index == 5 && value.isNotEmpty) {
                                final allFilled = _otpControllers
                                    .every((c) => c.text.isNotEmpty);
                                if (allFilled) _handleVerify();
                              }
                            },
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Timer
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isExpired
                          ? Container(
                              key: const ValueKey('expired'),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '⏰ Kode sudah kadaluarsa',
                                style: TextStyle(
                                  color: Color(0xFFE57373),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : Text(
                              key: const ValueKey('timer'),
                              'Kode berlaku selama ${_formatTime(_remainingSeconds)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: _remainingSeconds < 60
                                    ? const Color(0xFFE57373)
                                    : const Color(0xFF6B5E52),
                                fontWeight: _remainingSeconds < 60
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),

                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleVerify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC0430E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Verifikasi & Buat Akun',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Security notice
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5EE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFFFD8C2), width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined,
                              color: Color(0xFFC0430E), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Jaga kerahasiaan kode OTP',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C2C2C),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Jangan bagikan kode ini kepada siapa pun, termasuk pihak yang mengaku dari Kartara.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B5E52),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Resend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Tidak menerima kode?  ',
                          style:
                              TextStyle(fontSize: 14, color: Color(0xFF6B5E52)),
                        ),
                        GestureDetector(
                          onTap: (_remainingSeconds == 0 && !_isResending)
                              ? _handleResend
                              : null,
                          child: _isResending
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Color(0xFFC0430E),
                                  ),
                                )
                              : Text(
                                  _remainingSeconds > 0
                                      ? 'Kirim ulang (${_formatTime(_remainingSeconds)})'
                                      : 'Kirim ulang',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _remainingSeconds == 0
                                        ? const Color(0xFFC0430E)
                                        : const Color(0xFFB0A599),
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget kotak input OTP tunggal.
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 58,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: controller.text.isNotEmpty
              ? const Color(0xFFC0430E)
              : const Color(0xFFE0D5C7),
          width: controller.text.isNotEmpty ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: controller.text.isNotEmpty
                ? const Color(0xFFC0430E).withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2C2C2C),
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
      ),
    );
  }
}
