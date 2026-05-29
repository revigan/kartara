import 'package:flutter/material.dart';

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

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
          'Bantuan & FAQ',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header search illustration box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC0430E), Color(0xFFD4601A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ada yang Bisa\nKami Bantu?',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.3),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Temukan jawaban instan mengenai pembayaran, pengiriman, dan kendala transaksi Anda.',
                    style: TextStyle(color: Color(0xFFFFEDE0), fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Top Hot Topics
            const Text(
              'Pertanyaan Sering Diajukan (FAQ)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 16),

            // Accordion Items
            _buildFaqAccordion(
              'Bagaimana cara membayar pesanan via Midtrans?',
              'Ketuk tombol "Bayar Sekarang" di layar pembayaran. Anda akan diarahkan ke portal aman Midtrans Sandbox. Di sana, pilih salah satu metode pembayaran seperti QRIS atau Virtual Account bank, lalu selesaikan simulasi pembayarannya. Setelah sukses, Anda bisa menutup tab dan kembali ke aplikasi Kartara.',
            ),
            _buildFaqAccordion(
              'Berapa lama status pesanan berubah setelah dibayar?',
              'Status pesanan akan ter-update secara otomatis secara INSTAN berkat teknologi Webhook Latar Belakang kami. Begitu transaksi Anda "Settlement" di Midtrans, database server PocketBase akan langsung mengubah statusnya menjadi "Diproses" saat itu juga.',
            ),
            _buildFaqAccordion(
              'Mengapa status pesanan masih "Pending"?',
              'Status pending berarti pembayaran Anda belum terdeteksi sukses oleh sistem kami. Pastikan saldo e-wallet / m-banking Anda sudah terpotong, atau silakan ketuk tombol "Periksa Status Pembayaran" di dalam aplikasi untuk melakukan pengecekan manual secara aman.',
            ),
            _buildFaqAccordion(
              'Berapa lama waktu proses pengiriman barang?',
              'Setelah status pesanan Anda berubah menjadi "Diproses", penjual memiliki waktu maksimal 2x24 jam hari kerja untuk mengemas dan menyerahkan paket Anda ke kurir ekspedisi pilihan.',
            ),
            _buildFaqAccordion(
              'Bagaimana cara mengajukan pengembalian dana (refund)?',
              'Jika pesanan Anda dibatalkan atau barang tidak sesuai, Anda dapat menghubungi Customer Service kami dengan melampirkan video unboxing yang jelas. Dana refund akan otomatis ditambahkan ke saldo "Dompet Pribadi" Anda.',
            ),

            const SizedBox(height: 32),

            // Contact CS card at bottom
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFDDCC)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFDF3EB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.headset_mic_rounded, color: Color(0xFFC0430E), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Masih Punya Pertanyaan?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tim Layanan CS Kartara siap membantu kendala Anda 24/7.',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF7C7C7C), height: 1.3),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Menghubungkan ke Customer Service Kartara via Whatsapp...'),
                                backgroundColor: Color(0xFFC0430E),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text(
                            'Hubungi CS Sekarang →',
                            style: TextStyle(
                              color: Color(0xFFC0430E),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqAccordion(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F1F1)),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: const Color(0xFFC0430E),
          collapsedIconColor: const Color(0xFF7C7C7C),
          title: Text(
            question,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              height: 1.3,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Text(
                answer,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6C6C6C),
                  height: 1.5,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
