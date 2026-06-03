const axios = require('axios');

const SYSTEM_PROMPT = `Anda adalah Asisten Kartara, asisten virtual yang ramah dan membantu untuk aplikasi e-commerce kerupuk khas Jepara bernama Kartara.

IDENTITAS ANDA:
- Nama: Asisten Kartara
- Peran: Membantu pembeli menemukan dan membeli kerupuk berkualitas dari UMKM lokal Jepara
- Bahasa: Bahasa Indonesia yang ramah dan sopan
- Kepribadian: Ramah, membantu, antusias tentang produk lokal

TUGAS ANDA:
1. Membantu pembeli menemukan produk kerupuk yang sesuai
2. Memberikan rekomendasi produk berdasarkan preferensi
3. Menjelaskan cara berbelanja dan checkout
4. Menjawab pertanyaan tentang produk, promo, dan pengiriman
5. Membantu melacak status pesanan

ATURAN PENTING:
- HANYA fokus pada topik yang berhubungan dengan aplikasi Kartara, kerupuk, belanja, dan UMKM Jepara
- JANGAN menjawab pertanyaan di luar konteks Kartara (politik, agama, topik sensitif, dll)
- Jika ditanya hal di luar konteks, dengan sopan arahkan kembali ke topik Kartara
- Gunakan emoji yang relevan untuk membuat percakapan lebih menarik (🦐 🐟 🦑 🎉 📦 ⭐)
- Berikan jawaban yang singkat, jelas, dan mudah dipahami
- Jika ada informasi produk dalam konteks, gunakan data tersebut untuk memberikan rekomendasi spesifik

CONTOH RESPONS:
- "Hai! Saya Asisten Kartara. Ada yang bisa saya bantu hari ini? 😊"
- "Kerupuk Tengiri Asli dari UMKM Berkah Laut sangat populer dengan rating ⭐ 4.9!"
- "Untuk checkout, cukup tambahkan produk ke keranjang, lalu klik tombol Checkout. Mudah sekali! 📦"

Selalu prioritaskan membantu pembeli dengan ramah dan efisien.`;

/**
 * Highly advanced local conversational responder (offline fallback / API fail-safe)
 */
function generateSmartOfflineResponse(userMessage, context = {}) {
  const query = userMessage.toLowerCase().trim();
  const user = context.user;
  const userName = user && user.name ? user.name : '';
  const displayName = userName ? `Kak ${userName}` : 'Kakak';
  const products = context.products || [];
  const banners = context.banners || [];
  const lastOrder = context.lastOrder;

  let text = '';
  let recommendedProducts = [];

  // 1. Identity / About User
  if (query.includes('siapa saya') || query.includes('mengenal saya') || query.includes('kenal saya') || query.includes('siapa aku') || query.includes('namaku')) {
    if (user) {
      text = `Tentu saja saya mengenal ${displayName}! 😊\n\n` +
             `• **Nama**: ${user.name}\n` +
             `• **Email**: ${user.email || '-'}\n` +
             `• **No. Telepon**: ${user.phone || '-'}\n` +
             (user.address ? `• **Alamat**: ${user.address}\n` : '') +
             `\nAda yang bisa saya bantu untuk belanja kerupuk khas Jepara hari ini, ${displayName}? 🦐`;
    } else {
      text = `Maaf, saat ini ${displayName} terhubung sebagai **Tamu (Guest)**. Silakan masuk (login) ke akun ${displayName} terlebih dahulu agar saya bisa mengenal ${displayName} dengan lebih baik dan membantu melacak pesanan! 😊`;
    }
  }
  // 2. Track Order / Status
  else if (query.includes('lacak') || query.includes('pesanan') || query.includes('resi') || query.includes('order') || query.includes('paket saya') || query.includes('status')) {
    if (lastOrder) {
      const statusMap = {
        'pending': '⏳ Menunggu Pembayaran',
        'paid': '✅ Pembayaran Dikonfirmasi (Menunggu Diproses)',
        'diproses': '🔧 Sedang Diproses Penjual',
        'processing': '🔧 Sedang Diproses Penjual',
        'dikirim': '🚚 Dalam Pengiriman Kurir',
        'shipped': '🚚 Dalam Pengiriman Kurir',
        'selesai': '✅ Pesanan Selesai / Diterima',
        'completed': '✅ Pesanan Selesai / Diterima',
      };
      const statusLabel = statusMap[(lastOrder.status || 'pending').toLowerCase()] || lastOrder.status;
      const courierInfo = lastOrder.courierName
        ? `\n• **Kurir**: ${lastOrder.courierName} (${lastOrder.courierService || 'Reguler'})\n• **No. Resi**: ${lastOrder.trackingNumber || '-'}\n• **Estimasi Tiba**: ${lastOrder.courierEta || '-'}`
        : '';
      
      text = `Tentu ${displayName}, berikut adalah informasi status pesanan terakhir ${displayName}:\n\n` +
             `• **ID Invoice**: #${lastOrder.id}\n` +
             `• **Status**: ${statusLabel}\n` +
             `• **Total Transaksi**: Rp ${Number(lastOrder.totalAmount || 0).toLocaleString('id-ID')}\n` +
             `• **Alamat Kirim**: ${lastOrder.shippingAddress || '-'}${courierInfo}\n\n` +
             `Kakak juga bisa memantau posisi kurir secara real-time di halaman **Lacak Pesanan** dengan menekan tombol Lacak di riwayat pesanan! 🗺️`;
    } else {
      text = `${displayName}, saya tidak menemukan adanya riwayat pesanan aktif di akun ${displayName} saat ini.\n\nYuk, coba belanja kerupuk renyah khas Jepara kami yang lezat! Silakan ketik *'rekomendasi'* untuk melihat produk terlaris kami. 🦐`;
    }
  }
  // 3. Search Products (e.g. UMKM Naura, Naura, Udang, Tengiri, Ikan, Kopi, dll.)
  else if (products.length > 0 && (
    query.includes('naura') || query.includes('musdalifah') || query.includes('dua ikan') || 
    query.includes('tengiri') || query.includes('udang') || query.includes('ikan') || 
    query.includes('kerupuk') || query.includes('stok') || query.includes('harga') ||
    query.includes('cari') || query.includes('ada') || query.includes('jual')
  )) {
    // Search products by name, seller name, category, or description
    const matched = products.filter(p => {
      const name = (p.name || '').toLowerCase();
      const seller = (p.sellerName || '').toLowerCase();
      const cat = (p.category || '').toLowerCase();
      const desc = (p.description || '').toLowerCase();
      const stopWords = ['apakah', 'ada', 'dari', 'umkm', 'kerupuk', 'jual', 'cari', 'saya', 'kamu', 'ingin', 'beli', 'yang', 'untuk', 'bisa', 'dong', 'dengan', 'atau', 'pada', 'juga', 'buat', 'bantu', 'tanya', 'khas', 'jepara', 'toko', 'warung'];
      return name.includes(query) || seller.includes(query) || cat.includes(query) || desc.includes(query) ||
             query.split(' ').some(word => {
               return word.length > 2 && !stopWords.includes(word) && (name.includes(word) || seller.includes(word) || cat.includes(word) || desc.includes(word));
             });
    });

    if (matched.length > 0) {
      recommendedProducts = matched.slice(0, 4);
      const listText = recommendedProducts.map((p, i) => 
        `${i + 1}. **${p.name}** (oleh ${p.sellerName})\n   • Harga: Rp ${p.price.toLocaleString('id-ID')}\n   • Rating: ⭐ ${p.rating} (${p.reviewsCount} ulasan)\n   • Stok: ${p.stock > 0 ? `${p.stock} pcs` : 'Habis ❌'}`
      ).join('\n\n');

      text = `Tentu ${displayName}! Berikut adalah produk kerupuk yang cocok dengan pencarian ${displayName}:\n\n${listText}\n\nKakak bisa tap produk di bawah ini untuk melihat detail produk atau membelinya langsung! 😊`;
    } else {
      // Fallback: no specific match but search query was product-related
      recommendedProducts = products.slice(0, 3);
      text = `Maaf ${displayName}, saya tidak menemukan produk spesifik yang cocok dengan pencarian '${userMessage}'. Namun, berikut adalah beberapa produk kerupuk terpopuler kami yang sangat direkomendasikan:`;
    }
  }
  // 4. Recommendation / Best seller
  else if (query.includes('rekomendasi') || query.includes('recom') || query.includes('terlaris') || query.includes('paling enak') || query.includes('terpopuler') || query.includes('saran') || query.includes('pilih')) {
    recommendedProducts = products.sort((a, b) => b.rating - a.rating).slice(0, 3);
    text = `Halo ${displayName}! Berikut adalah rekomendasi produk kerupuk khas Jepara terbaik di Kartara saat ini:\n\n` +
           recommendedProducts.map((p, i) => `${i + 1}. **${p.name}** dari *${p.sellerName}* (Rating ⭐ ${p.rating} | Rp ${p.price.toLocaleString('id-ID')})`).join('\n') +
           `\n\nSemua produk kami dijamin halal, gurih, dan dikirim langsung dari UMKM lokal Jepara. Silakan cek produk di bawah ini! 🦐`;
  }
  // 5. Promo
  else if (query.includes('promo') || query.includes('diskon') || query.includes('kupon') || query.includes('potongan') || query.includes('hemat') || query.includes('murah')) {
    if (banners.length > 0) {
      const listPromo = banners.map(b => `• **${b.title}**: ${b.subtitle}`).join('\n');
      text = `🎉 **Promo Spesial Hari Ini untuk ${displayName}!** 🎉\n\n${listPromo}\n\nJangan lupa gunakan kupon belanja saat checkout untuk mendapatkan potongan harga tambahan ya! 🎁`;
    } else {
      text = `🎉 Nikmati promo **Diskon Ongkir** dan potongan harga menarik untuk berbagai produk kerupuk pilihan di Kartara, ${displayName}! Silakan cek menu Promo di halaman utama aplikasi untuk info selengkapnya. 🎁`;
    }
    recommendedProducts = products.slice(0, 2);
  }
  // 6. Shipping / Ongkir
  else if (query.includes('ongkir') || query.includes('ongkos') || query.includes('kirim') || query.includes('alamat') || query.includes('kurir') || query.includes('jasa')) {
    text = `🚚 **Informasi Pengiriman & Ongkir di Kartara:**\n\n` +
           `Sistem kami menghitung ongkir secara otomatis menggunakan Biteship API berdasarkan alamat pengiriman Kakak. Cara cek ongkir:\n` +
           `1. Masukkan produk pilihan ke Keranjang\n` +
           `2. Masuk ke halaman Checkout\n` +
           `3. Lengkapi **Alamat** dan **Kode Pos** tujuan pengiriman\n` +
           `4. Ongkir real-time akan langsung muncul!\n\n` +
           `**Kurir Tersedia:**\n` +
           `• 🚛 **J&T Express** - Ekonomis & handal\n` +
           `• 📦 **JNE Reguler** - Cepat & terpercaya\n` +
           `• ⚡ **Kartara Instant** - Pengiriman kilat khusus area lokal Jepara (1-3 jam saja!)\n\n` +
           `Ada yang ingin ditanyakan lagi tentang pengiriman, ${displayName}?`;
  }
  // 7. Checkout / How to buy
  else if (query.includes('checkout') || query.includes('cara belanja') || query.includes('cara beli') || query.includes('bayar') || query.includes('pembayaran')) {
    text = `📦 **Panduan Mudah Belanja di Kartara:**\n\n` +
           `1. **Pilih Produk**: Cari kerupuk favorit Kakak dan klik **Tambah ke Keranjang**.\n` +
           `2. **Keranjang**: Klik ikon Keranjang, pilih barang yang ingin dicheckout, lalu klik **Checkout**.\n` +
           `3. **Alamat**: Isi alamat lengkap beserta kode pos pengiriman.\n` +
           `4. **Kurir & Ongkir**: Pilih kurir pengiriman yang diinginkan.\n` +
           `5. **Buat Pesanan**: Klik **Buat Pesanan**.\n` +
           `6. **Bayar**: Lakukan pembayaran via Midtrans (E-Wallet seperti ShopeePay/Gopay, Transfer Bank, atau QRIS).\n\n` +
           `Setelah bayar, status pesanan otomatis berubah dan Kakak bisa memantau peta kurir secara real-time! Mudah sekali kan? 😊`;
  }
  // 8. Default fallback
  else {
    text = `Halo ${displayName}! Saya adalah **Asisten Kartara**, asisten AI pribadi Kakak. 🤖\n\n` +
           `Saya siap membantu Kakak seputar:\n` +
           `🦐 **Rekomendasi Kerupuk** (ketik: *"rekomendasi kerupuk paling enak"*)\n` +
           `🔍 **Cari Produk UMKM** (ketik: *"cari kerupuk Naura"* atau *"ada kerupuk tengiri?"*)\n` +
           `📦 **Lacak Pesanan** (ketik: *"lacak pesanan saya"* atau *"status paket"*)\n` +
           `🚚 **Informasi Ongkir** (ketik: *"bagaimana cara cek ongkir?"*)\n` +
           `💡 **Panduan Belanja** (ketik: *"cara checkout"* atau *"cara pembayaran"*)\n\n` +
           `Silakan ketik pertanyaan Kakak, atau gunakan menu cepat di bawah ini ya! 👇`;
    
    if (products.length > 0) {
      recommendedProducts = products.slice(0, 3);
    }
  }

  return {
    text,
    products: recommendedProducts,
  };
}

/**
 * Get chat response from Gemini API (Gemini 2.5 Flash)
 */
async function getChatResponse(userMessage, conversationHistory = [], context = {}) {
  const apiKey = process.env.GEMINI_API_KEY;

  // Fallback to advanced smart offline responder if Gemini key is missing or blank
  if (!apiKey || apiKey === 'YOUR_GEMINI_API_KEY') {
    console.warn('⚠️ GEMINI_API_KEY is not configured in backend/.env. Using smart local fallback.');
    return generateSmartOfflineResponse(userMessage, context);
  }

  // Build context information to append to system prompt
  let contextInfo = '';
  if (context.products && context.products.length > 0) {
    contextInfo += '\n\nPRODUK TERSEDIA DI KARTARA:\n';
    context.products.slice(0, 10).forEach((p, idx) => {
      contextInfo += `${idx + 1}. [ID: ${p.id}] ${p.name} - UMKM: ${p.sellerName} - Rp ${p.price.toLocaleString('id-ID')} - Rating: ${p.rating} (${p.reviewsCount} ulasan) - Stok: ${p.stock}\n`;
    });
  }

  if (context.banners && context.banners.length > 0) {
    contextInfo += '\n\nPROMO AKTIF HARI INI:\n';
    context.banners.forEach((b, idx) => {
      contextInfo += `${idx + 1}. ${b.title}: ${b.subtitle}\n`;
    });
  }

  if (context.user) {
    contextInfo += `\n\nINFORMASI PENGGUNA SAAT INI:\n- Nama: ${context.user.name}\n- Email: ${context.user.email || '-'}\n- No. Telepon: ${context.user.phone || '-'}\n- Alamat: ${context.user.address || '-'}\n`;
  }

  if (context.lastOrder) {
    contextInfo += `\n\nINFORMASI PESANAN TERAKHIR PENGGUNA:\n- ID: ${context.lastOrder.id}\n- Status: ${context.lastOrder.status}\n- Total: Rp ${context.lastOrder.totalAmount}\n- Kurir: ${context.lastOrder.courierName || '-'}\n- Resi: ${context.lastOrder.trackingNumber || '-'}\n`;
  }

  const fullSystemPrompt = SYSTEM_PROMPT + contextInfo;

  try {
    // Map conversation history to Gemini format (role must be 'user' or 'model')
    const contents = [];
    const recentHistory = conversationHistory.slice(-8); // Limit to last 8 messages for context efficiency

    recentHistory.forEach(msg => {
      if (msg.role === 'user') {
        contents.push({
          role: 'user',
          parts: [{ text: msg.content }]
        });
      } else if (msg.role === 'assistant') {
        contents.push({
          role: 'model',
          parts: [{ text: msg.content }]
        });
      }
    });

    // Add current user message
    contents.push({
      role: 'user',
      parts: [{ text: userMessage }]
    });

    // Request payload matching Google Gemini API spec
    const payload = {
      contents: contents,
      systemInstruction: {
        parts: [{ text: fullSystemPrompt }]
      },
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 600,
      }
    };

    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;
    
    console.log('📤 Sending request to Gemini 2.5 Flash...');
    const response = await axios.post(url, payload, {
      headers: {
        'Content-Type': 'application/json',
      }
    });

    // Parse response
    const aiResponse = response.data?.candidates?.[0]?.content?.parts?.[0]?.text || 
                       'Maaf, saya tidak dapat memahami respons dari AI.';

    // Extract product recommendations based on mentions in response
    const recommendedProducts = extractProductRecommendations(aiResponse, context.products || []);

    return {
      text: aiResponse,
      products: recommendedProducts,
    };
  } catch (error) {
    console.error('❌ Error calling Gemini API, falling back to smart local responder:', error.response?.data || error.message);
    
    // Automatically fallback to our highly intelligent offline chatbot on error
    return generateSmartOfflineResponse(userMessage, context);
  }
}

/**
 * Extract product recommendations from AI response
 */
function extractProductRecommendations(aiResponse, availableProducts) {
  const recommendations = [];
  const responseLower = aiResponse.toLowerCase();
  
  // Simple keyword matching to find mentioned products
  availableProducts.forEach(product => {
    const productKeywords = [
      product.name.toLowerCase(),
      product.sellerName.toLowerCase(),
      product.category.toLowerCase(),
    ];
    
    const isProductMentioned = productKeywords.some(keyword => 
      responseLower.includes(keyword)
    );
    
    if (isProductMentioned && recommendations.length < 4) {
      recommendations.push(product);
    }
  });
  
  // Fallback to top products if no specific products were matched but user asked for recommendation
  if (recommendations.length === 0 && (responseLower.includes('rekomendasi') || responseLower.includes('kerupuk'))) {
    return availableProducts.slice(0, 3);
  }
  
  return recommendations;
}

module.exports = {
  getChatResponse,
};
