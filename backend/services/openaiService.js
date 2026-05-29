const OpenAI = require('openai');

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

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
 * Get chat response from OpenAI
 */
async function getChatResponse(userMessage, conversationHistory = [], context = {}) {
  try {
    // Build context information
    let contextInfo = '';
    
    if (context.products && context.products.length > 0) {
      contextInfo += '\n\nPRODUK TERSEDIA:\n';
      context.products.forEach((p, idx) => {
        contextInfo += `${idx + 1}. ${p.name} - ${p.sellerName} - Rp ${p.price.toLocaleString('id-ID')} - Rating: ${p.rating} (${p.reviewsCount} ulasan) - Stok: ${p.stock}\n`;
      });
    }

    if (context.banners && context.banners.length > 0) {
      contextInfo += '\n\nPROMO AKTIF:\n';
      context.banners.forEach((b, idx) => {
        contextInfo += `${idx + 1}. ${b.title}: ${b.subtitle}\n`;
      });
    }

    // Build messages array for OpenAI
    const messages = [
      { role: 'system', content: SYSTEM_PROMPT + contextInfo },
    ];

    // Add conversation history (limit to last 10 messages)
    const recentHistory = conversationHistory.slice(-10);
    recentHistory.forEach(msg => {
      if (msg.role === 'user' || msg.role === 'assistant') {
        messages.push({
          role: msg.role,
          content: msg.content,
        });
      }
    });

    // Add current user message
    messages.push({
      role: 'user',
      content: userMessage,
    });

    // Call OpenAI API
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: messages,
      temperature: 0.7,
      max_tokens: 500,
    });

    const aiResponse = completion.choices[0].message.content;

    // Extract product recommendations if mentioned
    const recommendedProducts = extractProductRecommendations(aiResponse, context.products || []);

    return {
      text: aiResponse,
      products: recommendedProducts,
    };
  } catch (error) {
    console.error('Error calling OpenAI API:', error);
    
    // Fallback response if OpenAI fails
    return {
      text: 'Maaf, saya sedang mengalami gangguan. Silakan coba lagi dalam beberapa saat atau hubungi customer service kami. 🙏',
      products: [],
    };
  }
}

/**
 * Extract product recommendations from AI response
 */
function extractProductRecommendations(aiResponse, availableProducts) {
  const recommendations = [];
  
  // Simple keyword matching to find mentioned products
  availableProducts.forEach(product => {
    const productKeywords = [
      product.name.toLowerCase(),
      product.sellerName.toLowerCase(),
      product.category.toLowerCase(),
    ];
    
    const responseLower = aiResponse.toLowerCase();
    const isProductMentioned = productKeywords.some(keyword => 
      responseLower.includes(keyword)
    );
    
    if (isProductMentioned && recommendations.length < 4) {
      recommendations.push(product);
    }
  });
  
  return recommendations;
}

module.exports = {
  getChatResponse,
};
