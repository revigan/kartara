const axios = require('axios');

const SYSTEM_PROMPT = `Anda adalah Asisten Kartara — asisten virtual AI cerdas, ramah, dan personal untuk aplikasi e-commerce kerupuk khas Jepara bernama Kartara.

IDENTITAS:
- Nama: Asisten Kartara | Teknologi: Google Gemini AI
- Bahasa: Indonesia hangat & sopan | Sapaan: "Kak [nama]"
- Peran: Membantu pembeli menemukan, membandingkan, dan membeli kerupuk UMKM Jepara

══════════════════════════════════════
PANDUAN UTAMA — BACA SEMUA SEBELUM MENJAWAB
══════════════════════════════════════

1. PERCAKAPAN MULTI-TURN (SANGAT PENTING):
   Jika pesan user singkat seperti "yang lebih murah?", "ada yang lain?", "itu berapa?", "yang renyah?" dll:
   → Ini TINDAK LANJUT — cek RIWAYAT PERCAKAPAN untuk memahami konteksnya
   → Jawab berdasarkan produk/topik yang sudah dibahas sebelumnya
   → JANGAN tanya "produk apa?" jika konteks sudah jelas dari riwayat

2. REKOMENDASI PRODUK (BERDASARKAN DATA NYATA):
   → HANYA gunakan produk dari daftar "PRODUK TERSEDIA" — JANGAN karang nama produk sendiri
   → Filter harga: urutkan dari termurah jika user minta "murah/terjangkau"
   → Filter karakteristik: cocokkan dengan kolom Karakteristik di data produk
   → Format rekomendasi yang bagus:
      "🦐 **[Nama Produk]** • *[UMKM]* • Rp [harga] • ⭐[rating] • [karakteristik]"

3. CONTOH PERCAKAPAN IDEAL:
   User: "kerupuk renyah di bawah 25rb"
   Asisten: "Tentu Kak! Kerupuk renyah di bawah Rp 25.000:
   1. 🦐 **Kerupuk Ikan X** (UMKM Y) — Rp 15.000 | Renyah & Gurih ✓
   2. 🐟 **Kerupuk Tengiri Z** (UMKM W) — Rp 22.000 | Renyah, Original ✓
   Mau langsung tambah ke keranjang? 🛒"
   
   User: "ada yang lebih murah?"
   Asisten: "Yang paling murah dari tadi adalah **Kerupuk Ikan X** di Rp 15.000. Stoknya masih ready! Mau yang ini Kak? 😊"

4. JIKA TIDAK ADA PRODUK COCOK:
   → Katakan jujur: "Maaf Kak, belum ada produk [kriteria] yang tersedia."
   → Tawarkan alternatif terdekat dari data yang ada
   → JANGAN beri respons seolah produk ada padahal tidak di data

FORMAT JAWABAN:
- Terstruktur, padat, maksimal 5 poin — tidak bertele-tele
- Emoji relevan: 🦐 🐟 🎉 📦 ⭐ 🚚 💰 🛒
- **Teks tebal** untuk nama produk dan info penting
- Akhiri dengan pertanyaan tindak lanjut atau ajakan aksi ("Mau tambah ke keranjang? 🛒")
- Jika ada produk relevan di data, SELALU tampilkan minimal 1 produk spesifik

ATURAN KERAS:
- HANYA bahas Kartara, kerupuk, belanja online, UMKM Jepara — tolak topik lain dengan sopan
- JANGAN buat/karang nama produk, UMKM, atau harga yang tidak ada di data
- JANGAN katakan "tidak menemukan produk" jika ada produk relevan di data konteks
- Gunakan sapaan "Kak [nama]" jika ada data profil user

SUGGESTIONS FORMAT (wajib di akhir setiap respons):
[SUGGESTIONS:["saran1","saran2","saran3"]]
Pilih dari: "Lihat semua produk 🛍️", "Rekomendasi terlaris ⭐", "Cek promo hari ini 🎉", "Lacak pesananku 📦", "Cara checkout 📋", "Info ongkir 🚚", "Tanya soal produk 🦐", "Produk diskon 🏷️"

Selalu prioritaskan membantu pembeli dengan cara personal, hangat, dan efisien.`;

/**
 * Stop words to exclude during search keyword extraction
 */
const STOP_WORDS = new Set([
  'apakah','ada','dari','umkm','krupuk','jual','cari','saya','kamu',
  'aku','ingin','mau','beli','yang','untuk','bisa','dong','dengan','atau','pada',
  'juga','buat','bantu','tanya','khas','jepara','toko','warung',
  'tolong','mohon','minta','berikan','tunjukkan','tampilkan','lihat','rekomendasi',
  'rekomen','saran','pilih','pilihkan','coba','gimana','bagaimana','mana','apa',
  'siapa','kapan','kenapa','mengapa','punya','milik','nya','lah','kan','deh',
  'sekali','boleh','bolehkah','berapa','kisaran','sekitar','sampai',
  'antara','dan','di','ke','ini','itu','adalah','merupakan',
  'menjadi','sebagai','oleh','bagi','kepada','tentang','mengenai','seputar'
  // NOTE: kata karakteristik (renyah, gurih, pedas, dll) dan harga (murah, mahal)
  // SENGAJA tidak dimasukkan stop words agar bisa dipakai sebagai keyword pencarian
]);

/**
 * Sanitize user input — strip characters dangerous for DB filter injection
 */
function sanitizeInput(text) {
  if (!text || typeof text !== 'string') return '';
  return text
    .replace(/['"\\;><]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .substring(0, 500);
}

/**
 * Detect if the current message is a follow-up to a previous conversation turn.
 * Returns follow-up context or null.
 */
function resolveFollowUpQuery(message, history = []) {
  if (!history || history.length < 2) return null;
  const msgLower = message.toLowerCase().trim();

  const followUpPatterns = [
    'yang lebih murah', 'yang lebih mahal', 'ada yang lain', 'yang lain',
    'yang itu', 'produk tadi', 'itu tadi', 'yang tadi', 'ada lagi',
    'selain itu', 'alternatif lain', 'bandingkan', 'dibandingkan',
    'berapa harganya', 'stoknya berapa', 'dari mana asalnya',
    'gimana bedanya', 'bedanya apa', 'lebih bagus mana', 'sama tapi',
  ];

  const startsLikeFollowUp = ['yang ', 'itu ', 'ada ', 'gimana ', 'bedanya '].some(p => msgLower.startsWith(p));
  const containsFollowUp = followUpPatterns.some(p => msgLower.includes(p));
  // Very short message without product keywords also likely a follow-up
  const isVeryShortNonSearch = msgLower.length < 30 && !msgLower.includes('kerupuk') && !msgLower.includes('rekomendasi');

  if (!containsFollowUp && !(startsLikeFollowUp && isVeryShortNonSearch)) return null;

  const reversed = [...history].reverse();
  const lastUserMsg = reversed.find(h => h.role === 'user');
  const lastAssistantMsg = reversed.find(h => h.role === 'assistant');
  if (!lastUserMsg) return null;

  return {
    isFollowUp: true,
    previousQuery: lastUserMsg.content || '',
    previousResponse: lastAssistantMsg?.content || '',
  };
}

/**
 * Classify the primary intent of a user message for smarter context routing.
 * Returns an intent object with a 'type' property.
 */
function detectIntent(message, history = []) {
  const q = message.toLowerCase().trim();

  // 1. Follow-up check (must come before other checks)
  const followUp = resolveFollowUpQuery(message, history);
  if (followUp) return { type: 'FOLLOWUP', ...followUp };

  // 2. Order tracking
  if (['lacak', 'resi', 'posisi paket', 'cek pesanan', 'paket saya'].some(w => q.includes(w)) ||
      (q.includes('pesanan') && ['dimana', 'mana', 'posisi', 'status', 'gimana'].some(w => q.includes(w)))) {
    return { type: 'ORDER_TRACK' };
  }

  // 3. Checkout / payment
  if (['cara checkout', 'cara beli', 'cara belanja', 'cara bayar', 'metode bayar', 'metode pembayaran'].some(w => q.includes(w))) {
    return { type: 'CHECKOUT_HELP' };
  }

  // 4. Shipping info (without product search)
  const kws = extractKeywords(q);
  if (['ongkir', 'ongkos kirim', 'biaya kirim', 'info kirim', 'ekspedisi'].some(w => q.includes(w)) &&
      !q.includes('kerupuk') && kws.length === 0) {
    return { type: 'SHIPPING_INFO' };
  }

  // 5. Greeting (only if no product keywords present)
  if (['halo', 'hai ', 'hello', 'hi ', 'selamat pagi', 'selamat siang', 'selamat malam', 'selamat sore'].some(w => q.includes(w)) && kws.length === 0) {
    return { type: 'GREETING' };
  }

  // 6. Detect price & characteristic filters
  const constraints = parseSearchConstraints(q);
  const hasPriceFilter = constraints.maxPrice !== null || constraints.minPrice !== null ||
    ['murah', 'mahal', 'terjangkau', 'ekonomis', 'termurah', 'termahal', 'hemat'].some(w => q.includes(w));
  const charWords = ['renyah', 'gurih', 'pedas', 'tidak pedas', 'original', 'manis', 'asin', 'crispy', 'premium', 'spesial', 'enak', 'lezat'];
  const hasCharFilter = charWords.some(c => q.includes(c));

  if (hasPriceFilter && hasCharFilter) return { type: 'COMBINED_FILTER' };
  if (hasPriceFilter) return { type: 'PRICE_FILTER' };
  if (hasCharFilter) return { type: 'CHAR_FILTER' };

  // 7. General product search
  if (['kerupuk', 'krupuk', 'cari', 'rekomendasi', 'rekomen', 'saran', 'jual', 'produk'].some(w => q.includes(w)) || kws.length > 0) {
    return { type: 'SEARCH_PRODUCT' };
  }

  return { type: 'GENERAL' };
}

/**
 * Extract meaningful keywords from user message
 */
function extractKeywords(text) {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .split(/\s+/)
    .filter(w => w.length > 2 && !STOP_WORDS.has(w) && !/^\d+$/.test(w) && !/^\d+rb$/i.test(w) && !/^\d+k$/i.test(w));
}

/**
 * Detect max price limit from text (e.g. "di bawah 25000", "maksimal 30rb")
 */
function detectMaxPrice(text) {
  const rbMatch = text.match(/(?:bawah|kurang dari|maksimal|max|di bawah)\s*(\d+)\s*rb/i);
  if (rbMatch) return parseInt(rbMatch[1]) * 1000;
  const numMatch = text.match(/(?:bawah|kurang dari|maksimal|max|di bawah)\s*(?:rp\.?\s*)?(\d[\d.]*)/i);
  if (numMatch) return parseInt(numMatch[1].replace(/\./g, ''));
  return null;
}

/**
 * Detect exact price from text (e.g. "harga 5000", "5rb", "rp 10.000")
 * Returns the exact number or null. Only matches standalone numbers/prices
 * that are NOT preceded by a modifier like "di bawah", "kurang dari", etc.
 */
function detectExactPrice(text) {
  // Skip if text contains max/min price modifiers (those are handled separately)
  if (/(?:bawah|kurang dari|maksimal|max|di bawah|di atas|lebih dari|minimal|min)/i.test(text)) {
    return null;
  }
  // Match "Nrb" pattern (e.g. "5rb", "10rb")
  const rbMatch = text.match(/(\d+)\s*rb/i);
  if (rbMatch) return parseInt(rbMatch[1]) * 1000;
  // Match "rp N" or "rp. N" pattern
  const rpMatch = text.match(/rp\.?\s*(\d[\d.]*)/i);
  if (rpMatch) return parseInt(rpMatch[1].replace(/\./g, ''));
  // Match standalone number >= 1000 near price-related words
  const priceContextMatch = text.match(/(?:harga|price|seharga)\s*(\d[\d.]*)/i);
  if (priceContextMatch) {
    const val = parseInt(priceContextMatch[1].replace(/\./g, ''));
    if (val >= 1000) return val;
  }
  // Match standalone large number (likely a price)
  const standaloneMatch = text.match(/(?:^|\s)(\d{4,})(?:\s|$)/i);
  if (standaloneMatch) {
    const val = parseInt(standaloneMatch[1]);
    if (val >= 1000) return val;
  }
  return null;
}

/**
 * Parse advanced search constraints from user message (price, rating, stock, seller, category, sorting)
 */
function parseSearchConstraints(query) {
  const queryLower = query.toLowerCase();
  const constraints = {
    maxPrice: null,
    minPrice: null,
    exactPrice: null,
    minRating: null,
    onlyAvailable: false,
    sellerName: null,
    sortBy: null, // 'price_asc', 'price_desc', 'rating_desc', 'stock_desc'
  };

  // 1. Detect Max Price (e.g. "di bawah 25rb", "kurang dari 30.000")
  constraints.maxPrice = detectMaxPrice(queryLower);

  // 2. Detect Min Price (e.g., "di atas 10000", "lebih dari 20rb")
  const minPriceRbMatch = queryLower.match(/(?:di atas|lebih dari|minimal|min)\s*(\d+)\s*rb/i);
  if (minPriceRbMatch) {
    constraints.minPrice = parseInt(minPriceRbMatch[1]) * 1000;
  } else {
    const minPriceMatch = queryLower.match(/(?:di atas|lebih dari|minimal|min)\s*(?:rp\.?\s*)?(\d[\d.]*)/i);
    if (minPriceMatch) {
      constraints.minPrice = parseInt(minPriceMatch[1].replace(/\./g, ''));
    }
  }

  // 2b. Detect Exact Price — only if no max/min price modifiers were found
  if (constraints.maxPrice === null && constraints.minPrice === null) {
    const exactPrice = detectExactPrice(queryLower);
    if (exactPrice !== null) {
      constraints.exactPrice = exactPrice;
      // Create a ±20% range around the exact price
      constraints.minPrice = Math.floor(exactPrice * 0.8);
      constraints.maxPrice = Math.ceil(exactPrice * 1.2);
    }
  }

  // 3. Detect Min Rating (e.g., "rating di atas 4.5", "rating 4.8")
  const ratingMatch = queryLower.match(/rating\s*(?:di atas|minimal|>)?\s*(\d(?:[.,]\d)?)/i);
  if (ratingMatch) {
    constraints.minRating = parseFloat(ratingMatch[1].replace(',', '.'));
  }

  // 4. Detect Stock Availability (e.g. "yang ready", "ada stok", "ready stock")
  if (queryLower.includes('ready') || queryLower.includes('ada stok') || queryLower.includes('stok ada') || queryLower.includes('tidak habis') || queryLower.includes('stok ready') || queryLower.includes('tersedia')) {
    constraints.onlyAvailable = true;
  }

  // 5. Detect Seller Name (e.g., "toko mbak mus", "dari umkm dua ikan")
  const sellerMatch = queryLower.match(/(?:toko|umkm|dari penjual|penjual)\s+([a-zA-Z0-9\s]+)/i);
  if (sellerMatch) {
    const candidate = sellerMatch[1].trim();
    const candidateWords = candidate.split(/\s+/);
    if (candidateWords.length > 0 && candidateWords[0] !== 'yang' && candidateWords[0] !== 'di' && candidateWords[0] !== 'kerupuk' && candidateWords[0] !== 'krupuk') {
      constraints.sellerName = candidate;
    }
  }

  // 6. Detect Sorting Preferences
  if (queryLower.includes('paling murah') || queryLower.includes('harga terendah') || queryLower.includes('termurah') || queryLower.includes('murah')) {
    // Only sort by price if they specifically mention cheapest/terendah/termurah
    if (queryLower.includes('paling murah') || queryLower.includes('terendah') || queryLower.includes('termurah')) {
      constraints.sortBy = 'price_asc';
    }
  } else if (queryLower.includes('paling mahal') || queryLower.includes('harga tertinggi') || queryLower.includes('termahal')) {
    constraints.sortBy = 'price_desc';
  } else if (queryLower.includes('rating tertinggi') || queryLower.includes('rating terbaik') || queryLower.includes('paling enak') || queryLower.includes('terfavorit') || queryLower.includes('terbaik')) {
    constraints.sortBy = 'rating_desc';
  } else if (queryLower.includes('stok terbanyak') || queryLower.includes('stok paling banyak')) {
    constraints.sortBy = 'stock_desc';
  }

  return constraints;
}

/**
 * Search products by keywords and parsed search constraints
 */
function searchProducts(allProducts, keywords, constraints) {
  const hasConstraints = constraints.maxPrice !== null ||
                         constraints.minPrice !== null ||
                         constraints.exactPrice !== null ||
                         constraints.minRating !== null ||
                         constraints.onlyAvailable ||
                         constraints.sellerName !== null ||
                         constraints.sortBy !== null;

  // If no keywords and no constraints are specified, return empty search results
  if (keywords.length === 0 && !hasConstraints) {
    return [];
  }

  // Filter products based on active constraints
  const filtered = allProducts.filter(p => {
    // 1. Price constraint: Max Price
    if (constraints.maxPrice !== null && p.price > constraints.maxPrice) {
      return false;
    }
    // 2. Price constraint: Min Price
    if (constraints.minPrice !== null && p.price < constraints.minPrice) {
      return false;
    }
    // 3. Rating constraint
    if (constraints.minRating !== null && p.rating < constraints.minRating) {
      return false;
    }
    // 4. Stock constraint: only positive stock count
    if (constraints.onlyAvailable && (p.stock === undefined || p.stock <= 0)) {
      return false;
    }
    // 5. Seller constraint
    if (constraints.sellerName !== null) {
      const pSeller = (p.sellerName || '').toLowerCase();
      const matchSeller = constraints.sellerName.toLowerCase();
      if (!pSeller.includes(matchSeller) && !matchSeller.includes(pSeller)) {
        return false;
      }
    }
    return true;
  });

  // Calculate score for keyword relevance
  const scored = filtered.map(p => {
    const nameLower = (p.name || '').toLowerCase();
    const descLower = (p.description || '').toLowerCase();
    const sellerLower = (p.sellerName || '').toLowerCase();
    const categoryLower = (p.category || '').toLowerCase();
    // Normalize characteristics: support both array of strings and comma-separated string
    const charsArray = Array.isArray(p.characteristics)
      ? p.characteristics
      : (typeof p.characteristics === 'string' ? p.characteristics.split(',') : []);
    const charsText = charsArray.map(c => c.toLowerCase().trim()).join(' ');
    const allText = [nameLower, descLower, sellerLower, categoryLower, charsText].join(' ');

    let score = 0;
    if (keywords.length > 0) {
      for (const kw of keywords) {
        if (nameLower.includes(kw)) {
          score += 5; // Strong match: product name
        }
        // Characteristic match gets high boost (e.g. "renyah", "gurih", "pedas")
        if (charsText.includes(kw)) {
          score += 4;
        }
        if (descLower.includes(kw)) {
          score += 3;
        }
        if (categoryLower.includes(kw) || sellerLower.includes(kw)) {
          score += 2;
        }
        // Partial match fallback
        if (allText.includes(kw)) {
          score += 1;
        }
      }
    } else {
      // Baseline score of 1 if product matches filters but no keywords specified
      score = 1;
    }

    return { product: p, score };
  });

  // Filter out any zero score matches
  const results = scored
    .filter(s => s.score > 0)
    .map(s => s.product);

  // Apply sorting preferences
  if (constraints.sortBy === 'price_asc') {
    results.sort((a, b) => a.price - b.price);
  } else if (constraints.sortBy === 'price_desc') {
    results.sort((a, b) => b.price - a.price);
  } else if (constraints.sortBy === 'rating_desc') {
    results.sort((a, b) => b.rating - a.rating || b.reviewsCount - a.reviewsCount);
  } else if (constraints.sortBy === 'stock_desc') {
    results.sort((a, b) => b.stock - a.stock);
  } else {
    // Default sorting: Relevance score, then rating
    results.sort((a, b) => {
      const scoreA = scored.find(s => s.product.id === a.id)?.score || 0;
      const scoreB = scored.find(s => s.product.id === b.id)?.score || 0;
      return scoreB - scoreA || b.rating - a.rating;
    });
  }

  return results;
}

/**
 * Extract suggestions from AI response text
 */
function extractSuggestions(responseText) {
  const match = responseText.match(/\[SUGGESTIONS:(.*?)\]/s);
  if (match) {
    try {
      return JSON.parse(match[1]);
    } catch (e) {
      return getDefaultSuggestions();
    }
  }
  return getDefaultSuggestions();
}

/**
 * Clean suggestions marker from response text
 */
function cleanResponseText(text) {
  return text.replace(/\[SUGGESTIONS:.*?\]/s, '').trim();
}

/**
 * Get default suggestions
 */
function getDefaultSuggestions() {
  return ['Rekomendasi terlaris ⭐', 'Cek promo hari ini 🎉', 'Info ongkir 🚚'];
}

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
  let suggestions = [];

  const keywords = extractKeywords(query);
  const constraints = parseSearchConstraints(query);

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
      text = `Maaf, saat ini ${displayName} terhubung sebagai **Tamu (Guest)**. Silakan masuk ke akun terlebih dahulu agar saya bisa mengenal Kakak lebih baik dan membantu melacak pesanan! 😊`;
    }
    suggestions = ['Lihat semua produk 🛍️', 'Rekomendasi terlaris ⭐', 'Lacak pesananku 📦'];
  }
  // 2. Track Order / Status
  else if (query.includes('lacak') || query.includes('pesanan') || query.includes('resi') || query.includes('order') || query.includes('paket saya') || query.includes('status')) {
    if (lastOrder) {
      const statusMap = {
        'pending': '⏳ Menunggu Pembayaran',
        'paid': '✅ Pembayaran Dikonfirmasi',
        'diproses': '🔧 Sedang Diproses Penjual',
        'processing': '🔧 Sedang Diproses Penjual',
        'dikirim': '🚚 Dalam Pengiriman Kurir',
        'shipped': '🚚 Dalam Pengiriman Kurir',
        'selesai': '✅ Pesanan Selesai',
        'completed': '✅ Pesanan Selesai',
      };
      const statusLabel = statusMap[(lastOrder.status || 'pending').toLowerCase()] || lastOrder.status;
      const courierInfo = lastOrder.courierName
        ? `\n• **Kurir**: ${lastOrder.courierName} (${lastOrder.courierService || 'Reguler'})\n• **No. Resi**: ${lastOrder.trackingNumber || '-'}\n• **Estimasi Tiba**: ${lastOrder.courierEta || '-'}`
        : '';
      text = `Tentu ${displayName}! Ini status pesanan terakhir Kakak:\n\n` +
             `• **ID Invoice**: #${lastOrder.id}\n` +
             `• **Status**: ${statusLabel}\n` +
             `• **Total**: Rp ${Number(lastOrder.totalAmount || 0).toLocaleString('id-ID')}${courierInfo}\n\n` +
             `Kakak bisa memantau posisi kurir secara real-time di halaman **Lacak Pesanan**! 🗺️`;
    } else {
      text = `${displayName}, saya tidak menemukan riwayat pesanan aktif saat ini.\n\nYuk, coba belanja kerupuk renyah khas Jepara kami! Ketik *"rekomendasi"* untuk melihat produk terlaris. 🦐`;
    }
    suggestions = ['Lihat semua produk 🛍️', 'Rekomendasi terlaris ⭐', 'Cara checkout 📋'];
  }
  // 3. Smart Product Search — berdasarkan keyword, harga, dan karakteristik
  else if (products.length > 0 && (
    keywords.length > 0 ||
    constraints.maxPrice !== null ||
    constraints.minPrice !== null ||
    constraints.minRating !== null ||
    constraints.onlyAvailable ||
    constraints.sellerName !== null ||
    constraints.sortBy !== null ||
    query.includes('kerupuk') || query.includes('krupuk') ||
    query.includes('cari') || query.includes('ada') || query.includes('jual') ||
    query.includes('stok') || query.includes('harga') || query.includes('rekomendasi') ||
    query.includes('terlaris') || query.includes('terpopuler') || query.includes('enak') ||
    query.includes('gurih') || query.includes('renyah') || query.includes('pedas') ||
    query.includes('original') || query.includes('crispy') || query.includes('manis') ||
    query.includes('saran') || query.includes('pilih') || query.includes('bagus') || query.includes('murah') || query.includes('mahal')
  )) {
    const matched = searchProducts(products, keywords, constraints);

    if (matched.length > 0) {
      recommendedProducts = matched.slice(0, 4);
      const listText = recommendedProducts.map((p, i) => {
        // Normalize characteristics
        const charsArray = Array.isArray(p.characteristics)
          ? p.characteristics
          : (typeof p.characteristics === 'string' && p.characteristics
              ? p.characteristics.split(',').map(c => c.trim())
              : []);
        const charsLabel = charsArray.length > 0 ? `\n   • Karakteristik: ${charsArray.join(', ')}` : '';
        return `${i + 1}. **${p.name}** (${p.sellerName})\n   • Harga: Rp ${p.price.toLocaleString('id-ID')}\n   • Rating: ⭐ ${p.rating} | Stok: ${p.stock > 0 ? `${p.stock} pcs` : 'Habis ❌'}${charsLabel}`;
      }).join('\n\n');

      // Build descriptive response text reflecting current search filters
      let filterDescriptions = [];
      // Show characteristic keywords if they were found
      const charKeywords = keywords.filter(kw =>
        ['renyah','gurih','pedas','original','manis','asin','crispy','super','premium','spesial'].includes(kw)
      );
      const otherKeywords = keywords.filter(kw => !charKeywords.includes(kw));
      if (otherKeywords.length) filterDescriptions.push(`kata kunci "${otherKeywords.join(', ')}"`);
      if (charKeywords.length) filterDescriptions.push(`karakteristik **${charKeywords.join(', ')}**`);
      if (constraints.exactPrice) {
        filterDescriptions.push(`harga sekitar Rp ${constraints.exactPrice.toLocaleString('id-ID')}`);
      } else {
        if (constraints.maxPrice) filterDescriptions.push(`harga di bawah **Rp ${constraints.maxPrice.toLocaleString('id-ID')}**`);
        if (constraints.minPrice) filterDescriptions.push(`harga di atas **Rp ${constraints.minPrice.toLocaleString('id-ID')}**`);
      }
      if (constraints.minRating) filterDescriptions.push(`rating minimal ⭐ ${constraints.minRating}`);
      if (constraints.onlyAvailable) filterDescriptions.push(`stok tersedia (ready)`);
      if (constraints.sellerName) filterDescriptions.push(`penjual "${constraints.sellerName}"`);

      let sortingDesc = '';
      if (constraints.sortBy === 'price_asc') sortingDesc = ' (diurutkan dari yang termurah)';
      else if (constraints.sortBy === 'price_desc') sortingDesc = ' (diurutkan dari yang termahal)';
      else if (constraints.sortBy === 'rating_desc') sortingDesc = ' (diurutkan dari rating tertinggi)';
      else if (constraints.sortBy === 'stock_desc') sortingDesc = ' (diurutkan dari stok terbanyak)';

      const filterText = filterDescriptions.length ? ' dengan ' + filterDescriptions.join(', ') : '';
      text = `Tentu ${displayName}! Berikut rekomendasi kerupuk${filterText}${sortingDesc}:\n\n${listText}\n\nTap produk di bawah untuk melihat detail atau langsung tambah ke keranjang! 😊`;
    } else {
      // Tidak ada hasil → tampilkan terlaris sebagai alternatif
      recommendedProducts = [...products].sort((a, b) => b.rating - a.rating).slice(0, 3);
      // Describe what was searched
      let searchedFor = keywords.length > 0 ? `"${keywords.join(', ')}"` : 'kriteria tersebut';
      if (constraints.maxPrice) searchedFor += ` di bawah Rp ${constraints.maxPrice.toLocaleString('id-ID')}`;
      text = `Maaf ${displayName}, tidak ada produk kerupuk dengan ${searchedFor} yang tersedia saat ini. 😔\n\nTapi ini produk **terpopuler** kami yang mungkin Kakak sukai:\n\n` +
        recommendedProducts.map((p, i) => {
          const charsArray = Array.isArray(p.characteristics)
            ? p.characteristics
            : (typeof p.characteristics === 'string' && p.characteristics
                ? p.characteristics.split(',').map(c => c.trim()) : []);
          const chars = charsArray.length > 0 ? ` | ${charsArray.slice(0, 2).join(', ')}` : '';
          return `${i + 1}. **${p.name}** — Rp ${p.price.toLocaleString('id-ID')}${chars}\n   ⭐ ${p.rating} dari *${p.sellerName}*`;
        }).join('\n\n') +
        `\n\nMau cari dengan kriteria lain, ${displayName}?`;
    }
    suggestions = ['Lihat semua produk 🛍️', 'Produk diskon 🏷️', 'Info ongkir 🚚'];
  }
  // 4. Promo
  else if (query.includes('promo') || query.includes('diskon') || query.includes('kupon') || query.includes('potongan') || query.includes('hemat') || query.includes('murah')) {
    if (banners.length > 0) {
      const listPromo = banners.map(b => `• **${b.title}**: ${b.subtitle}`).join('\n');
      text = `🎉 **Promo Spesial untuk ${displayName}!**\n\n${listPromo}\n\nJangan lupa gunakan kupon belanja saat checkout! 🎁`;
    } else {
      text = `🎉 Nikmati promo **Diskon Ongkir** dan potongan harga menarik untuk produk kerupuk pilihan di Kartara, ${displayName}!\n\nCek menu Promo di halaman utama untuk info selengkapnya. 🎁`;
    }
    recommendedProducts = products.slice(0, 2);
    suggestions = ['Lihat semua produk 🛍️', 'Cara checkout 📋', 'Info ongkir 🚚'];
  }
  // 5. Shipping / Ongkir
  else if (query.includes('ongkir') || query.includes('ongkos') || query.includes('kirim') || query.includes('alamat') || query.includes('kurir') || query.includes('jasa')) {
    text = `🚚 **Informasi Pengiriman di Kartara:**\n\n` +
           `Ongkir dihitung otomatis menggunakan Biteship API. Cara cek:\n` +
           `1. Masukkan produk ke **Keranjang**\n` +
           `2. Masuk ke halaman **Checkout**\n` +
           `3. Isi **Alamat** + **Kode Pos** tujuan\n` +
           `4. Ongkir real-time langsung muncul!\n\n` +
           `**Kurir Tersedia:**\n` +
           `• 🚛 **J&T Express** — Ekonomis & handal\n` +
           `• 📦 **JNE Reguler** — Cepat & terpercaya\n` +
           `• ⚡ **Kartara Instant** — Ekspres lokal Jepara (1-3 jam!)\n\n` +
           `Ada lagi yang ingin ditanyakan, ${displayName}?`;
    suggestions = ['Cara checkout 📋', 'Rekomendasi terlaris ⭐', 'Lihat semua produk 🛍️'];
  }
  // 6. Checkout / How to buy
  else if (query.includes('checkout') || query.includes('cara belanja') || query.includes('cara beli') || query.includes('bayar') || query.includes('pembayaran')) {
    text = `📦 **Panduan Belanja di Kartara, ${displayName}:**\n\n` +
           `1. **Pilih Produk** → Klik **Tambah ke Keranjang**\n` +
           `2. **Keranjang** → Pilih item, klik **Checkout**\n` +
           `3. **Alamat** → Isi alamat lengkap + kode pos\n` +
           `4. **Kurir** → Pilih kurir & lihat ongkir otomatis\n` +
           `5. **Bayar** → Via QRIS, E-Wallet, atau Transfer Bank\n\n` +
           `Setelah bayar, Kakak bisa pantau kurir secara **real-time** di peta! 😊`;
    suggestions = ['Lihat semua produk 🛍️', 'Info ongkir 🚚', 'Lacak pesananku 📦'];
  }
  // 7. Greeting
  else if (query.includes('halo') || query.includes('hai') || query.includes('hello') || query.includes('hi') || query.includes('selamat')) {
    text = `Hai ${displayName}! Selamat datang di **Asisten Kartara** 🤖✨\n\n` +
           `Saya adalah asisten AI yang siap membantu Kakak berbelanja kerupuk khas Jepara yang lezat!\n\n` +
           `Ada yang bisa saya bantu hari ini? 😊`;
    if (products.length > 0) recommendedProducts = products.slice(0, 2);
    suggestions = ['Rekomendasi terlaris ⭐', 'Cek promo hari ini 🎉', 'Lihat semua produk 🛍️'];
  }
  // 8. Default fallback
  else {
    text = `Halo ${displayName}! Saya **Asisten Kartara**, asisten AI pribadi Kakak. 🤖\n\n` +
           `Saya bisa membantu dengan:\n` +
           `🦐 **Rekomendasi** — *"rekomendasi kerupuk terenak"*\n` +
           `🔍 **Cari Produk** — *"ada kerupuk tengiri?"*\n` +
           `📦 **Lacak Pesanan** — *"status pesanan saya"*\n` +
           `🚚 **Info Ongkir** — *"cara cek ongkir"*\n` +
           `💡 **Panduan Beli** — *"cara checkout"*\n\n` +
           `Silakan ketik pertanyaan Kakak! 👇`;
    if (products.length > 0) recommendedProducts = products.slice(0, 3);
    suggestions = ['Rekomendasi terlaris ⭐', 'Cek promo hari ini 🎉', 'Info ongkir 🚚'];
  }

  return { text, products: recommendedProducts, suggestions };
}

/**
 * Get chat response from Gemini API (Gemini 2.5 Flash)
 */
async function getChatResponse(userMessage, conversationHistory = [], context = {}) {
  const apiKey = process.env.GEMINI_API_KEY;

  if (!apiKey || apiKey === 'YOUR_GEMINI_API_KEY') {
    console.warn('⚠️ GEMINI_API_KEY not configured. Using smart local fallback.');
    return generateSmartOfflineResponse(userMessage, context);
  }

  // Build context information
  let contextInfo = '';

  // --- Intent context: tell the AI WHY these products are shown ---
  if (context.intent) {
    const intentLabels = {
      'SEARCH_PRODUCT': 'Mencari Produk',
      'PRICE_FILTER': 'Filter Berdasarkan Harga',
      'CHAR_FILTER': 'Filter Berdasarkan Karakteristik',
      'COMBINED_FILTER': 'Filter Harga + Karakteristik',
      'ORDER_TRACK': 'Lacak Pesanan',
      'CHECKOUT_HELP': 'Bantuan Checkout',
      'SHIPPING_INFO': 'Info Pengiriman',
      'FOLLOWUP': 'Tindak Lanjut Percakapan Sebelumnya',
      'GREETING': 'Sapaan',
      'GENERAL': 'Pertanyaan Umum',
    };
    contextInfo += `\n\nINTENT USER: ${intentLabels[context.intent.type] || context.intent.type}\n`;
    if (context.intent.type === 'FOLLOWUP' && context.intent.previousQuery) {
      contextInfo += `PERTANYAAN SEBELUMNYA: "${context.intent.previousQuery}"\n`;
      contextInfo += `INSTRUKSI: Jawab pertanyaan tindak lanjut berdasarkan konteks percakapan di atas.\n`;
    }
    if (context.searchContext) {
      contextInfo += `KRITERIA PENCARIAN: ${context.searchContext}\n`;
    }
  }

  // --- Products: up to 15, with full detail ---
  if (context.products && context.products.length > 0) {
    contextInfo += `\n\nPRODUK TERSEDIA (${context.products.length} produk, sudah difilter):\n`;
    context.products.slice(0, 15).forEach((p, idx) => {
      const charsArray = Array.isArray(p.characteristics)
        ? p.characteristics
        : (typeof p.characteristics === 'string' && p.characteristics
            ? p.characteristics.split(',').map(c => c.trim())
            : []);
      const chars = charsArray.length > 0 ? ` | Karakteristik: [${charsArray.join(', ')}]` : ' | Karakteristik: -';
      const stock = p.stock > 0 ? `${p.stock} pcs` : 'HABIS';
      const desc = p.description ? ` | Desc: ${p.description.substring(0, 60)}` : '';
      contextInfo += `${idx + 1}. [ID:${p.id}] **${p.name}** | UMKM: ${p.sellerName} | Harga: Rp ${p.price.toLocaleString('id-ID')} | Rating: ⭐${p.rating} (${p.reviewsCount}x) | Stok: ${stock}${chars}${desc}\n`;
    });
    contextInfo += '\n→ Gunakan data produk di atas. Sebutkan nama & UMKM secara spesifik. JANGAN karang produk baru.\n';
  }

  if (context.banners && context.banners.length > 0) {
    contextInfo += '\nPROMO AKTIF:\n';
    context.banners.forEach((b, idx) => {
      contextInfo += `${idx + 1}. ${b.title}: ${b.subtitle}\n`;
    });
  }

  if (context.user) {
    contextInfo += `\nPENGGUNA: ${context.user.name} | Email: ${context.user.email || '-'} | Telp: ${context.user.phone || '-'} | Alamat: ${context.user.address || '-'}\n`;
  }

  if (context.lastOrder) {
    contextInfo += `\nPESANAN TERAKHIR: ID #${context.lastOrder.id} | Status: ${context.lastOrder.status} | Total: Rp ${Number(context.lastOrder.totalAmount).toLocaleString('id-ID')} | Kurir: ${context.lastOrder.courierName || '-'} | Resi: ${context.lastOrder.trackingNumber || '-'}\n`;
  }

  const fullSystemPrompt = SYSTEM_PROMPT + contextInfo;

  try {
    const contents = [];
    const recentHistory = conversationHistory.slice(-12); // Keep last 12 messages for better multi-turn context

    recentHistory.forEach(msg => {
      if (msg.role === 'user') {
        contents.push({ role: 'user', parts: [{ text: msg.content }] });
      } else if (msg.role === 'assistant') {
        contents.push({ role: 'model', parts: [{ text: msg.content }] });
      }
    });

    contents.push({ role: 'user', parts: [{ text: userMessage }] });

    const payload = {
      contents,
      systemInstruction: { parts: [{ text: fullSystemPrompt }] },
      generationConfig: {
        temperature: 0.3,      // Lower = more accurate, less hallucination
        maxOutputTokens: 1200, // Higher = complete responses, no mid-sentence cuts
        topK: 40,              // Vocabulary diversity
        topP: 0.95,            // Nucleus sampling for balance
      }
    };

    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;
    
    console.log('📤 Sending request to Gemini 2.5 Flash...');
    const response = await axios.post(url, payload, {
      headers: { 'Content-Type': 'application/json' }
    });

    const rawResponse = response.data?.candidates?.[0]?.content?.parts?.[0]?.text || 
                       'Maaf, saya tidak dapat memahami respons dari AI.';

    const suggestions = extractSuggestions(rawResponse);
    const aiResponse = cleanResponseText(rawResponse);
    const recommendedProducts = extractProductRecommendations(aiResponse, context.products || [], userMessage);

    return { text: aiResponse, products: recommendedProducts, suggestions };
  } catch (error) {
    console.error('❌ Gemini API error, falling back to smart local responder:', error.response?.data || error.message);
    return generateSmartOfflineResponse(userMessage, context);
  }
}

/**
 * Extract product recommendations from AI response and user search constraints
 */
function extractProductRecommendations(aiResponse, availableProducts, userMessage = '') {
  const recommendations = [];
  const responseLower = aiResponse.toLowerCase();

  // 1. Primary: match from user message keywords + constraints (highest priority)
  if (userMessage) {
    const queryLower = userMessage.toLowerCase();
    const keywords = extractKeywords(queryLower);
    const constraints = parseSearchConstraints(queryLower);

    const hasConstraints = constraints.maxPrice !== null ||
                           constraints.minPrice !== null ||
                           constraints.exactPrice !== null ||
                           constraints.minRating !== null ||
                           constraints.onlyAvailable ||
                           constraints.sellerName !== null ||
                           constraints.sortBy !== null;

    if (keywords.length > 0 || hasConstraints) {
      const searchResults = searchProducts(availableProducts, keywords, constraints);
      searchResults.forEach(p => {
        if (!recommendations.some(r => r.id === p.id)) {
          recommendations.push(p);
        }
      });
    }
  }

  // 2. Secondary: add products explicitly mentioned in the AI response (by name or seller)
  availableProducts.forEach(product => {
    if (recommendations.length >= 4) return;
    const nameLower = product.name.toLowerCase();
    const sellerLower = product.sellerName.toLowerCase();

    // Check if AI explicitly mentioned this product by name or seller name
    const isMentionedByName = nameLower.split(' ').some(word =>
      word.length > 3 && responseLower.includes(word)
    );
    const isMentionedBySeller = sellerLower.split(' ').some(word =>
      word.length > 3 && responseLower.includes(word)
    );

    if ((isMentionedByName || isMentionedBySeller) && !recommendations.some(r => r.id === product.id)) {
      recommendations.push(product);
    }
  });

  // 3. Tertiary: if AI response mentions characteristics, match products that have them
  if (recommendations.length < 2 && userMessage) {
    const queryLower = userMessage.toLowerCase();
    // Detect characteristic keywords in user message
    const charKeywords = ['renyah', 'gurih', 'pedas', 'tidak pedas', 'original', 'manis',
      'asin', 'super', 'ekstra', 'spesial', 'premium', 'crispy', 'crunchy', 'soft'];
    const matchedCharKeywords = charKeywords.filter(ck => queryLower.includes(ck));

    if (matchedCharKeywords.length > 0) {
      availableProducts.forEach(product => {
        if (recommendations.length >= 4) return;
        const charsArray = Array.isArray(product.characteristics)
          ? product.characteristics
          : (typeof product.characteristics === 'string'
              ? product.characteristics.split(',').map(c => c.trim())
              : []);
        const charsLower = charsArray.map(c => c.toLowerCase()).join(' ');
        const hasCharMatch = matchedCharKeywords.some(ck => charsLower.includes(ck));
        if (hasCharMatch && !recommendations.some(r => r.id === product.id)) {
          recommendations.push(product);
        }
      });
    }
  }

  // 4. Final fallback: if nothing matched but user is asking for recommendations,
  //    return the top-rated available products (NOT all products blindly)
  if (recommendations.length === 0) {
    const isRecommendationRequest = responseLower.includes('rekomendasi') ||
      responseLower.includes('kerupuk') || responseLower.includes('krupuk') ||
      (userMessage && (userMessage.toLowerCase().includes('rekomendasi') ||
        userMessage.toLowerCase().includes('kerupuk')));
    if (isRecommendationRequest) {
      return [...availableProducts]
        .sort((a, b) => b.rating - a.rating || b.reviewsCount - a.reviewsCount)
        .slice(0, 4);
    }
  }

  return recommendations.slice(0, 4);
}

module.exports = {
  getChatResponse,
  extractKeywords,
  parseSearchConstraints,
  searchProducts,
  detectIntent,
  sanitizeInput,
};
