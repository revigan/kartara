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

    // Sanitize input
    const cleanMessage = geminiService.sanitizeInput(message);

    // Detect intent from the message + conversation history
    const history = conversationHistory || [];
    const intent = geminiService.detectIntent(cleanMessage, history);

    // For FOLLOWUP intents, augment the effective query with previous context
    // so the DB filter and keyword search can find relevant products
    let effectiveQuery = cleanMessage;
    if (intent.type === 'FOLLOWUP' && intent.previousQuery) {
      effectiveQuery = `${intent.previousQuery} ${cleanMessage}`;
    }

    // Parse keywords and constraints from the effective query
    const keywords = geminiService.extractKeywords(effectiveQuery);
    const constraints = geminiService.parseSearchConstraints(effectiveQuery);

    // Build pocketbase filter — price/stock/rating only (reliable indexed fields)
    const pbFilterParts = [];
    if (constraints.maxPrice !== null) pbFilterParts.push(`price <= ${constraints.maxPrice}`);
    if (constraints.minPrice !== null) pbFilterParts.push(`price >= ${constraints.minPrice}`);
    if (constraints.minRating !== null) pbFilterParts.push(`rating >= ${constraints.minRating}`);
    if (constraints.onlyAvailable) pbFilterParts.push(`stock > 0`);
    if (constraints.sellerName !== null) pbFilterParts.push(`sellerName ~ "${constraints.sellerName}"`);

    const pbFilter = pbFilterParts.length > 0 ? pbFilterParts.join(' && ') : '';

    let pbSort = '-rating';  // Default: best rated first
    if (constraints.sortBy === 'price_asc') pbSort = 'price';
    else if (constraints.sortBy === 'price_desc') pbSort = '-price';
    else if (constraints.sortBy === 'rating_desc') pbSort = '-rating';
    else if (constraints.sortBy === 'stock_desc') pbSort = '-stock';

    // Fetch from DB (price/availability filtered)
    let dbProducts = await pocketbaseService.getProducts({ filter: pbFilter, sort: pbSort });
    if (dbProducts.length === 0) {
      dbProducts = await pocketbaseService.getProducts({ sort: pbSort });
    }

    // Apply in-memory keyword + characteristic search on top of DB results
    let products = dbProducts;
    if (keywords.length > 0) {
      const inMemoryResults = geminiService.searchProducts(dbProducts, keywords, {
        maxPrice: null, minPrice: null, exactPrice: null,
        minRating: null, onlyAvailable: false, sellerName: null, sortBy: null,
      });
      if (inMemoryResults.length > 0) products = inMemoryResults;
    }

    // Build human-readable search context for AI
    const searchParts = [];
    if (constraints.maxPrice) searchParts.push(`harga di bawah Rp ${constraints.maxPrice.toLocaleString('id-ID')}`);
    if (constraints.minPrice) searchParts.push(`harga di atas Rp ${constraints.minPrice.toLocaleString('id-ID')}`);
    if (keywords.length > 0) searchParts.push(`kata kunci: ${keywords.join(', ')}`);
    if (intent.type !== 'GENERAL') searchParts.push(`intent: ${intent.type}`);
    const searchContext = searchParts.length > 0 ? searchParts.join(' | ') : null;

    const [banners, user, lastOrder] = await Promise.all([
      pocketbaseService.getBanners(),
      pocketbaseService.getUserByPhoneOrId(userId),
      pocketbaseService.getLatestOrder(userId || 'guest'),
    ]);

    const context = {
      products,
      banners: banners.slice(0, 3),
      user,
      lastOrder,
      intent,
      searchContext,
    };

    const aiResponse = await geminiService.getChatResponse(
      cleanMessage,
      history,
      context
    );

    // Determine if this is an order tracking request
    const trackingOrder = (intent.type === 'ORDER_TRACK' && lastOrder) ? lastOrder : null;

    res.json({
      response: aiResponse.text,
      products: aiResponse.products || [],

      suggestions: aiResponse.suggestions || [],
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
    let suggestions = [];

    switch (action) {
      case 'rekomendasi_kerupuk':
      case 'Rekomendasi terlaris ⭐':
        products = await pocketbaseService.getTopRatedProducts(4);
        response = '🌟 Berikut rekomendasi kerupuk **terbaik dan terlaris** di Kartara untuk Kakak:';
        suggestions = ['Produk diskon 🏷️', 'Info ongkir 🚚', 'Cara checkout 📋'];
        break;

      case 'produk_terlaris':
        products = await pocketbaseService.getBestSellingProducts(4);
        response = '⭐ Ini dia produk kerupuk **terlaris** minggu ini:';
        suggestions = ['Cek promo hari ini 🎉', 'Info ongkir 🚚', 'Cara checkout 📋'];
        break;

      case 'promo_hari_ini':
      case 'Cek promo hari ini 🎉':
        const banners = await pocketbaseService.getBanners();
        const promoText = banners.length > 0
          ? banners.map(b => `• **${b.title}**: ${b.subtitle}`).join('\n')
          : 'Belum ada promo khusus hari ini, tapi produk kami selalu terjangkau! 😊';
        response = `🎉 **Promo & Penawaran Spesial Kartara:**\n\n${promoText}\n\nJangan lupa gunakan kupon saat checkout untuk hemat lebih banyak! 🎁`;
        products = await pocketbaseService.getTopRatedProducts(2);
        suggestions = ['Lihat semua produk 🛍️', 'Cara checkout 📋', 'Info ongkir 🚚'];
        break;

      case 'cara_checkout':
      case 'Cara checkout 📋':
        response = '📦 **Panduan Mudah Belanja di Kartara:**\n\n' +
          '1. **Pilih Produk** → Klik "Tambah ke Keranjang"\n' +
          '2. **Keranjang** → Pilih item, klik "Checkout"\n' +
          '3. **Alamat** → Isi alamat lengkap + kode pos\n' +
          '4. **Kurir** → Pilih kurir, ongkir otomatis muncul\n' +
          '5. **Bayar** → Via QRIS, E-Wallet, atau Transfer Bank\n\n' +
          'Setelah bayar, pantau kurir secara **real-time** di peta! 🗺️';
        suggestions = ['Lihat semua produk 🛍️', 'Info ongkir 🚚', 'Tanya soal produk 🦐'];
        break;

      case 'cek_ongkir':
      case 'Info ongkir 🚚':
        products = await pocketbaseService.getTopRatedProducts(3);
        response = '🚚 **Informasi Pengiriman & Ongkir Kartara:**\n\n' +
          'Ongkir dihitung **otomatis** saat checkout:\n\n' +
          '1. Masukkan produk ke Keranjang\n' +
          '2. Klik Checkout\n' +
          '3. Isi Alamat + Kode Pos\n' +
          '4. Ongkir real-time langsung muncul!\n\n' +
          '**Kurir Tersedia:**\n' +
          '• 🚛 **J&T Express** — Ekonomis, 2-3 hari\n' +
          '• 📦 **JNE Reguler** — Cepat, 1-2 hari\n' +
          '• ⚡ **Kartara Instant** — Lokal Jepara, 1-3 jam!\n\n' +
          'Mulai belanja sekarang! 🦐';
        suggestions = ['Cara checkout 📋', 'Rekomendasi terlaris ⭐', 'Lihat semua produk 🛍️'];
        break;

      case 'lacak_pesanan':
      case 'Lacak pesananku 📦':
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

            response = `📦 **Status Pesanan Terakhir:**\n\n• **ID Invoice**: #${lastOrder.id}\n• **Status**: ${statusLabel}\n• **Total**: Rp ${Number(lastOrder.totalAmount).toLocaleString('id-ID')}\n${courierInfo}\n\nTap tombol di bawah untuk buka peta tracking! 🗺️`;
          } else {
            response = '📦 **Lacak Pesanan:**\n\nAnda belum memiliki pesanan aktif.\n\nSetelah berbelanja dan membayar, Kakak bisa memantau posisi kurir secara **real-time** lewat peta interaktif!\n\nYuk mulai belanja kerupuk renyah khas Jepara! 🦐';
          }
        } catch (e) {
          response = '📦 Masukkan nomor invoice untuk melacak pesanan secara langsung!';
        }
        suggestions = ['Lihat semua produk 🛍️', 'Rekomendasi terlaris ⭐', 'Cara checkout 📋'];
        break;

      case 'Produk diskon 🏷️':
        products = await pocketbaseService.getTopRatedProducts(4);
        response = '🏷️ **Produk dengan Penawaran Terbaik:**\n\nIni beberapa produk pilihan dengan harga terjangkau dari UMKM lokal Jepara:';
        suggestions = ['Cara checkout 📋', 'Info ongkir 🚚', 'Cek promo hari ini 🎉'];
        break;

      case 'Lihat semua produk 🛍️':
        products = await pocketbaseService.getTopRatedProducts(4);
        response = '🛍️ **Katalog Kerupuk Kartara:**\n\nIni beberapa produk pilihan terbaik kami dari UMKM Jepara:';
        suggestions = ['Rekomendasi terlaris ⭐', 'Cek promo hari ini 🎉', 'Info ongkir 🚚'];
        break;

      case 'Tanya soal produk 🦐':
        products = await pocketbaseService.getTopRatedProducts(3);
        response = '🦐 **Tentang Kerupuk Kartara:**\n\nSemua produk kami adalah kerupuk autentik khas Jepara, dibuat oleh UMKM lokal yang berpengalaman.\n\n' +
          '• **Bahan**: Ikan Tengiri / Udang segar pilihan\n' +
          '• **Produksi**: Langsung dari UMKM Jepara\n' +
          '• **Garansi**: Halal & Higienis\n\n' +
          'Ada produk spesifik yang ingin Kakak tanyakan?';
        suggestions = ['Rekomendasi terlaris ⭐', 'Lihat semua produk 🛍️', 'Info ongkir 🚚'];
        break;

      default:
        // Try to use it as a chat message
        try {
          const allProducts = await pocketbaseService.getProducts();
          const context = { products: allProducts };
          const aiResult = await geminiService.getChatResponse(action, [], context);
          response = aiResult.text;
          products = aiResult.products || [];
          suggestions = aiResult.suggestions || ['Rekomendasi terlaris ⭐', 'Cek promo hari ini 🎉', 'Info ongkir 🚚'];
        } catch (e) {
          response = 'Maaf, saya tidak mengerti permintaan tersebut. Silakan ketik pertanyaan Anda.';
          suggestions = ['Rekomendasi terlaris ⭐', 'Cek promo hari ini 🎉', 'Info ongkir 🚚'];
        }
    }

    res.json({
      response,
      products,
      suggestions,
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
    res.json({
      response,
      products,
      suggestions: ['Info ongkir 🚚', 'Cara checkout 📋', 'Cek promo hari ini 🎉'],
      timestamp: new Date().toISOString(),
    });
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
        suggestions: ['Lacak pesananku 📦', 'Lihat semua produk 🛍️'],
        timestamp: new Date().toISOString(),
      });
    }
    const statusMap = {
      'pending': 'Pesanan menunggu pembayaran.',
      'paid': 'Pembayaran dikonfirmasi, menunggu diproses penjual.',
      'diproses': 'Pesanan sedang diproses oleh penjual.',
      'processing': 'Pesanan sedang diproses oleh penjual.',
      'dikirim': 'Pesanan sedang dalam pengiriman.',
      'shipped': 'Pesanan sedang dalam pengiriman.',
      'selesai': 'Pesanan telah selesai. Terima kasih!',
      'completed': 'Pesanan telah selesai. Terima kasih!',
    };
    const statusText = statusMap[(order.status || 'pending').toLowerCase()] || `Status: ${order.status}`;
    res.json({
      response: `📦 Status Pesanan #${orderId}:\n\n${statusText}`,
      order,
      suggestions: ['Lihat semua produk 🛍️', 'Rekomendasi terlaris ⭐'],
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Error in getOrderStatus:', error);
    res.status(500).json({ error: 'Failed to get order status', message: error.message });
  }
}

module.exports = { handleChat, handleQuickReply, getRecommendation, getOrderStatus };
