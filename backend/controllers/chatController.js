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

    // Get context from PocketBase
    const products = await pocketbaseService.getProducts();
    const banners = await pocketbaseService.getBanners();

    // Build context for Gemini 2.5 Flash
    const context = {
      products: products.slice(0, 10), // Limit to top 10 products
      banners: banners.slice(0, 3), // Limit to top 3 banners
    };

    // Get AI response
    const aiResponse = await geminiService.getChatResponse(
      message,
      conversationHistory || [],
      context
    );

    // Auto-detect if user is asking about order tracking/delivery location
    let trackingOrder = null;
    const msgLower = message.toLowerCase();
    if (msgLower.includes('pesanan saya dimana') || msgLower.includes('lacak') || msgLower.includes('posisi paket') || msgLower.includes('status paket')) {
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
    res.status(500).json({ 
      error: 'Failed to process chat message',
      message: error.message 
    });
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
        response = '📦 Cara checkout di Kartara sangat mudah:\n\n1. Pilih produk yang Anda inginkan\n2. Klik tombol "Tambah ke Keranjang"\n3. Buka keranjang belanja Anda\n4. Pilih produk yang ingin dibeli\n5. Klik "Checkout"\n6. Isi alamat pengiriman\n7. Pilih metode pembayaran\n8. Selesaikan pembayaran\n\nAda yang ingin ditanyakan lagi?';
        break;

      case 'cek_ongkir':
        products = await pocketbaseService.getTopRatedProducts(3);
        response = '🚚 **Cek Ongkir Otomatis**:\n\nAnda dapat mengecek ongkos kirim secara instan saat melakukan Checkout produk. Cukup isi Alamat Lengkap dan Kode Pos di formulir Checkout, kurir seperti J&T Express, JNE, dan Kartara Instant beserta estimasi pengirimannya akan langsung muncul otomatis!\n\nSilakan pilih kerupuk di bawah ini untuk memulai belanja Anda! 🦐';
        break;

      case 'lacak_pesanan':
        try {
          const lastOrder = await pocketbaseService.getLatestOrder(userId || 'guest');
          if (lastOrder) {
            response = `📦 **Pelacakan Pesanan Terakhir**:\n\n• **ID Invoice**: #${lastOrder.id}\n• **Status**: **${lastOrder.status.toUpperCase()}**\n• **Total Belanja**: Rp ${lastOrder.totalAmount.toLocaleString('id-ID')}\n• **Metode**: ${lastOrder.paymentMethod || 'Midtrans'}\n\nKetik *"Pesanan saya dimana?"* untuk menampilkan peta pelacakan interaktif secara instan! 📍`;
          } else {
            response = '📦 **Lacak Pesanan**:\n\nAnda belum memiliki pesanan aktif. Setelah Anda berbelanja dan melakukan pembayaran, Anda dapat memantau status kurir secara real-time lewat peta interaktif bertenaga OpenStreetMap!\n\nSilakan pesan produk kerupuk renyah khas Jepara kami sekarang! 🐟';
          }
        } catch (e) {
          response = '📦 Ketikkan nomor invoice pesanan Anda untuk melacak status pesanan secara langsung!';
        }
        break;

      default:
        response = 'Maaf, saya tidak mengerti permintaan Anda. Silakan pilih opsi lain atau ketik pertanyaan Anda.';
    }

    res.json({
      response,
      products,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error in handleQuickReply:', error);
    res.status(500).json({ 
      error: 'Failed to process quick reply',
      message: error.message 
    });
  }
}

/**
 * Get product recommendations
 */
async function getRecommendation(req, res) {
  try {
    const { category, userId } = req.body;

    let products = [];
    if (category && category !== 'Semua') {
      products = await pocketbaseService.getProductsByCategory(category, 4);
    } else {
      products = await pocketbaseService.getTopRatedProducts(4);
    }

    const response = products.length > 0
      ? `Berikut rekomendasi kerupuk ${category || 'terbaik'} untuk Anda:`
      : 'Maaf, belum ada produk yang tersedia saat ini.';

    res.json({
      response,
      products,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error in getRecommendation:', error);
    res.status(500).json({ 
      error: 'Failed to get recommendations',
      message: error.message 
    });
  }
}

/**
 * Get order status
 */
async function getOrderStatus(req, res) {
  try {
    const { orderId, userId } = req.body;

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

    let statusText = '';
    switch (order.status.toLowerCase()) {
      case 'pending':
        statusText = 'Pesanan Anda sedang menunggu pembayaran.';
        break;
      case 'diproses':
        statusText = 'Pesanan Anda sedang diproses oleh penjual.';
        break;
      case 'dikirim':
        statusText = 'Pesanan Anda sedang dalam pengiriman.';
        break;
      case 'selesai':
        statusText = 'Pesanan Anda telah selesai. Terima kasih!';
        break;
      default:
        statusText = `Status pesanan: ${order.status}`;
    }

    res.json({
      response: `📦 Status Pesanan #${orderId}:\n\n${statusText}`,
      order,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error in getOrderStatus:', error);
    res.status(500).json({ 
      error: 'Failed to get order status',
      message: error.message 
    });
  }
}

module.exports = {
  handleChat,
  handleQuickReply,
  getRecommendation,
  getOrderStatus,
};
