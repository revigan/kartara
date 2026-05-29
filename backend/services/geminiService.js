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
 * Get chat response from Gemini API (Gemini 2.5 Flash)
 */
async function getChatResponse(userMessage, conversationHistory = [], context = {}) {
  const apiKey = process.env.GEMINI_API_KEY;

  // Build context information to append to system prompt
  let contextInfo = '';
  if (context.products && context.products.length > 0) {
    contextInfo += '\n\nPRODUK TERSEDIA DI KARTARA:\n';
    context.products.forEach((p, idx) => {
      contextInfo += `${idx + 1}. [ID: ${p.id}] ${p.name} - UMKM: ${p.sellerName} - Rp ${p.price.toLocaleString('id-ID')} - Rating: ${p.rating} (${p.reviewsCount} ulasan) - Stok: ${p.stock}\n`;
    });
  }

  if (context.banners && context.banners.length > 0) {
    contextInfo += '\n\nPROMO AKTIF HARI INI:\n';
    context.banners.forEach((b, idx) => {
      contextInfo += `${idx + 1}. ${b.title}: ${b.subtitle}\n`;
    });
  }

  const fullSystemPrompt = SYSTEM_PROMPT + contextInfo;

  // Fallback offline mock assistant if Gemini API key is missing
  if (!apiKey || apiKey === 'YOUR_GEMINI_API_KEY') {
    console.warn('⚠️ GEMINI_API_KEY is not configured in backend/.env. Using smart mock fallback.');
    
    // Smart offline keyword-based response generator
    let mockResponseText = '';
    const query = userMessage.toLowerCase();
    
    if (query.includes('rekomendasi') || query.includes('cari') || query.includes('beli') || query.includes('pilih')) {
      mockResponseText = '🦐 Asisten Kartara merekomendasikan **Kerupuk Tengiri Asli** dari UMKM Berkah Laut atau **Kerupuk Udang Super** dari Mbak Mus! Keduanya renyah, gurih, dan sangat disukai pelanggan kami. Silakan cek produk di bawah ini untuk melihat detailnya! 😊';
    } else if (query.includes('promo') || query.includes('diskon') || query.includes('kupon')) {
      mockResponseText = '🎉 Hari ini kami memiliki beberapa promo menarik untuk Anda! Nikmati diskon ongkir dan potongan harga khusus untuk produk UMKM pilihan. Cek tab Promo di halaman utama ya! ⭐';
    } else if (query.includes('checkout') || query.includes('bayar') || query.includes('cara')) {
      mockResponseText = '📦 Cara belanja di Kartara mudah sekali:\n1. Pilih kerupuk favorit Anda\n2. Klik "Tambah ke Keranjang"\n3. Buka ikon Keranjang di pojok kanan atas\n4. Klik "Checkout" lalu selesaikan pembayaran via Midtrans!\n\nApakah ada hal lain yang bisa saya bantu?';
    } else {
      mockResponseText = 'Halo! Saya Asisten Kartara. Ada yang bisa saya bantu hari ini? Saya bisa memberikan rekomendasi kerupuk khas Jepara terlezat, info promo hari ini, atau memandu Anda melakukan checkout pesanan. 😊';
    }

    const recommendedProducts = extractProductRecommendations(mockResponseText, context.products || []);

    return {
      text: mockResponseText + '\n\n*(Catatan: Asisten saat ini berjalan dalam mode simulasi offline karena GEMINI_API_KEY belum dikonfigurasi di backend/.env)*',
      products: recommendedProducts,
    };
  }

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
    console.error('❌ Error calling Gemini 2.5 Flash API:', error.response?.data || error.message);
    
    // Graceful fallback on API error
    return {
      text: 'Maaf, saya sedang mengalami kendala saat berkomunikasi dengan server AI kami. Pastikan koneksi internet Anda stabil atau coba lagi sesaat lagi ya. 🙏',
      products: [],
    };
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
