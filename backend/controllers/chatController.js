const geminiService = require('../services/geminiService');
const pocketbaseService = require('../services/pocketbaseService');

/**
 * Handle main chat conversation
 */
async function handleChat(req, res) {
  try {
    const { message, conversationHistory, userId } = req.body;

    if (!message || !message.trim()) {
      return res.status(400).json({ error: 'Message is required' });
    }

    const products = await pocketbaseService.getProducts();
    const banners = await pocketbaseService.getBanners();
    const user = await pocketbaseService.getUserByPhoneOrId(userId);
    const lastOrder = await pocketbaseService.getLatestOrder(userId || 'guest');

    const context = {
      products,
      banners: banners.slice(0, 3),
      user,
      lastOrder,
    };

    const aiResponse = await geminiService.getChatResponse(
      message,
      conversationHistory || [],
      context
    );

    // Deteksi intent tracking pesanan dari pesan user
    let trackingOrder = null;
    const msgLower = message.toLowerCase();
    const isTrackingIntent =
      msgLower.includes('pesanan') && (msgLower.includes('dimana') || msgLower.includes('mana') || msgLower.includes('posisi') || msgLower.includes('status')) ||
      msgLower.includes('lacak') ||
      msgLower.includes('resi') ||
      msgLower.includes('posisi paket') ||
      msgLower.includes('cek pesanan') ||
      msgLower.includes('status pesanan') ||
      msgLower.includes('paket saya');

    if (isTrackingIntent) {
      try {
        const lastOrder = await pocketbaseService.getLatestOrder(userId || 'guest');
        if (lastOrder) {
          trackingOrder = lastOrder;
        }
      } catch (e) {
        console.warn('Failed to fetch latest order for tracking context:', e.message);
      }
    }

    res.json({
      response: aiResponse.text,
      products: aiResponse.products || [],
      order: trackingOrder,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error in handleChat:', error);
    res.status(500).json({ error: 'Failed to process chat message', message: error.message });
  }
}

/**
 * Handle quick reply actions
 */
async function handleQuickReply(req, res) {
  try {
    const { action, userId } = req.body;

    if (!action) {
      return res.status(400).json({ error: 'Action is required' });
    }

    let response = '';
    let products = [];
    let order = null;

    switch (action) {
      case 'rekomendasi_kerupuk':
        products = await pocketbaseService.getTopRatedProducts(4);
        response = '🦐 Berikut rekomendasi kerupuk terbaik untuk Anda:';
        break;

      case 'produk_terlaris':
        products = await pocketbaseService.getBestSellingProducts(4);
        response = '⭐ Ini dia produk kerupuk terlaris minggu ini:';
        break;

      case 'promo_hari_ini':
        const banners = await pocketbaseService.getBanners();
        const promoText = banners.length > 0
          ? banners.map(b => `• ${b.title}: ${b.subtitle}`).join('\n')
          : 'Belum ada promo khusus hari ini.';
        response = `🎉 Promo Hari Ini:\n\n${promoText}`;
        break;

      case 'cara_checkout':
        response = '📦 Cara checkout di Kartara sangat mudah:\n\n1. Pilih produk yang Anda inginkan\n2. Klik "Tambah ke Keranjang"\n3. Buka keranjang belanja\n4. Pilih produk yang ingin dibeli\n5. Klik "Checkout"\n6. Isi alamat & kode pos pengiriman\n7. Ongkir otomatis dihitung!\n8. Pilih kurir yang diinginkan\n9. Selesaikan pembayaran via Midtrans\n\nAda yang ingin ditanyakan?';
        break;

      case 'cek_ongkir':
        products = await pocketbaseService.getTopRatedProducts(3);
        response = '🚚 **Cek Ongkir Otomatis di Kartara!**\n\nSistem ongkir kami bekerja secara otomatis:\n\n1. Masukkan produk ke keranjang\n2. Klik Checkout\n3. Isi **Alamat Lengkap** + **Kode Pos** tujuan\n4. Ongkir langsung dihitung otomatis!\n\nKurir tersedia:\n• 🚛 **J&T Express** — Termurah, estimasi 2-3 hari\n• 📦 **JNE Reguler** — Cepat, estimasi 1-2 hari\n• ⚡ **Kartara Instant** — Ekspres lokal Jepara, 1-3 jam\n\nMulai belanja kerupuk pilihan di bawah ini! 🦐';
        break;

      case 'lacak_pesanan':
        try {
          const lastOrder = await pocketbaseService.getLatestOrder(userId || 'guest');
          if (lastOrder) {
            order = lastOrder;
            const statusMap = {
              'pending': '⏳ Menunggu Pembayaran',
              'paid': '✅ Sudah Dibayar',
              'diproses': '🔧 Sedang Diproses',
              'processing': '🔧 Sedang Diproses',
              'dikirim': '🚚 Dalam Pengiriman',
              'shipped': '🚚 Dalam Pengiriman',
              'selesai': '✅ Pesanan Selesai',
              'completed': '✅ Pesanan Selesai',
            };
            const statusLabel = statusMap[(lastOrder.status || 'pending').toLowerCase()] || lastOrder.status;
            const courierInfo = lastOrder.courierName
              ? `• **Kurir**: ${lastOrder.courierName}\n• **No. Resi**: ${lastOrder.trackingNumber}\n• **ETA**: ${lastOrder.courierEta}`
              : '';

            response = `📦 **Status Pesanan Terakhir Anda:**\n\n• **ID Invoice**: #${lastOrder.id}\n• **Status**: ${statusLabel}\n• **Total**: Rp ${Number(lastOrder.totalAmount).toLocaleString('id-ID')}\n${courierInfo}\n\nTap tombol di bawah untuk membuka peta tracking real-time! 🗺️`;
          } else {
            response = '📦 **Lacak Pesanan**:\n\nAnda belum memiliki pesanan aktif saat ini.\n\nSetelah berbelanja dan membayar, Anda dapat memantau status dan posisi kurir secara **real-time** melalui peta OpenStreetMap interaktif!\n\nYuk mulai belanja kerupuk renyah khas Jepara! 🦐';
          }
        } catch (e) {
          response = '📦 Masukkan nomor invoice Anda untuk melacak pesanan secara langsung!';
        }
        break;

      default:
        response = 'Maaf, saya tidak mengerti permintaan Anda. Silakan pilih opsi lain atau ketik pertanyaan Anda.';
    }

    res.json({
      response,
      products,
      order,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error in handleQuickReply:', error);
    res.status(500).json({ error: 'Failed to process quick reply', message: error.message });
  }
}

/**
 * Get product recommendations
 */
async function getRecommendation(req, res) {
  try {
    const { category } = req.body;
    let products = [];
    if (category && category !== 'Semua') {
      products = await pocketbaseService.getProductsByCategory(category, 4);
    } else {
      products = await pocketbaseService.getTopRatedProducts(4);
    }
    const response = products.length > 0
      ? `Berikut rekomendasi kerupuk ${category || 'terbaik'} untuk Anda:`
      : 'Maaf, belum ada produk yang tersedia saat ini.';
    res.json({ response, products, timestamp: new Date().toISOString() });
  } catch (error) {
    console.error('Error in getRecommendation:', error);
    res.status(500).json({ error: 'Failed to get recommendations', message: error.message });
  }
}

/**
 * Get order status
 */
async function getOrderStatus(req, res) {
  try {
    const { orderId } = req.body;
    if (!orderId) {
      return res.status(400).json({ error: 'Order ID is required' });
    }
    const order = await pocketbaseService.getOrderById(orderId);
    if (!order) {
      return res.json({
        response: `Maaf, pesanan dengan ID ${orderId} tidak ditemukan. Pastikan ID pesanan Anda benar.`,
        order: null,
        timestamp: new Date().toISOString(),
      });
    }
    const statusMap = {
      'pending': 'Pesanan Anda sedang menunggu pembayaran.',
      'paid': 'Pembayaran dikonfirmasi, menunggu diproses penjual.',
      'diproses': 'Pesanan Anda sedang diproses oleh penjual.',
      'processing': 'Pesanan Anda sedang diproses oleh penjual.',
      'dikirim': 'Pesanan Anda sedang dalam pengiriman.',
      'shipped': 'Pesanan Anda sedang dalam pengiriman.',
      'selesai': 'Pesanan Anda telah selesai. Terima kasih!',
      'completed': 'Pesanan Anda telah selesai. Terima kasih!',
    };
    const statusText = statusMap[(order.status || 'pending').toLowerCase()] || `Status pesanan: ${order.status}`;
    res.json({
      response: `📦 Status Pesanan #${orderId}:\n\n${statusText}`,
      order,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error in getOrderStatus:', error);
    res.status(500).json({ error: 'Failed to get order status', message: error.message });
  }
}

module.exports = {
  handleChat,
  handleQuickReply,
  getRecommendation,
  getOrderStatus,
};
