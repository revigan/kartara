import 'package:flutter/material.dart';

class PersonalWalletScreen extends StatelessWidget {
  const PersonalWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Dompet Pribadi',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Premium Card with HSL tail-end gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3C72).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'KartaraPay',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_user, color: Colors.greenAccent, size: 12),
                            SizedBox(width: 4),
                            Text('Aktif', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Rp 750.000',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '**** **** **** 8920',
                    style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Actions Panel
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(context, Icons.add_circle_outline, 'Isi Saldo'),
                _buildActionButton(context, Icons.arrow_upward_rounded, 'Kirim'),
                _buildActionButton(context, Icons.account_balance_rounded, 'Tarik Dana'),
                _buildActionButton(context, Icons.history_rounded, 'Minta Dana'),
              ],
            ),
            const SizedBox(height: 32),

            // Transaction History Section Title
            const Text(
              'Riwayat Transaksi',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 16),

            // Mock List of Transactions
            _buildTransactionItem(
              title: 'Refund Pembatalan Pesanan #KRK0921',
              subtitle: '24 Mei 2026 • 10:15 WIB',
              amount: '+Rp 120.000',
              isIncome: true,
            ),
            _buildTransactionItem(
              title: 'Pembelian Sepatu Kets Casual',
              subtitle: '22 Mei 2026 • 15:30 WIB',
              amount: '-Rp 340.000',
              isIncome: false,
            ),
            _buildTransactionItem(
              title: 'Top Up via BCA Virtual Account',
              subtitle: '20 Mei 2026 • 09:00 WIB',
              amount: '+Rp 500.000',
              isIncome: true,
            ),
            _buildTransactionItem(
              title: 'Pembelian Kemeja Batik Modern',
              subtitle: '18 Mei 2026 • 11:20 WIB',
              amount: '-Rp 180.000',
              isIncome: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fitur "$label" akan segera hadir untuk memudahkan transaksi Anda!'),
            backgroundColor: const Color(0xFF1E3C72),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFDDCC)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(icon, color: const Color(0xFF1E3C72), size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem({
    required String title,
    required String subtitle,
    required String amount,
    required bool isIncome,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F1F1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isIncome ? const Color(0xFFE8F8F0) : const Color(0xFFFDECE8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.add_rounded : Icons.remove_rounded,
              color: isIncome ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF7C7C7C)),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
