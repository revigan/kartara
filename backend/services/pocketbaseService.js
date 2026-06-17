const axios = require('axios');

const POCKETBASE_URL = process.env.POCKETBASE_URL || 'http://127.0.0.1:8090';

/**
 * Get all products from PocketBase
 */
async function getProducts(options = {}) {
  try {
    const { filter, sort, perPage } = options;
    const params = {
      sort: sort || '-created',
      filter: filter ? `isActive = true && (${filter})` : 'isActive = true',
      perPage: perPage || 50,
    };
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/products/records`, {
      params,
    });
    return response.data.items.map(formatProduct);
  } catch (error) {
    console.error('Error fetching products from PocketBase:', error.message);
    return [];
  }
}

async function getTopRatedProducts(limit = 4) {
  try {
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/products/records`, {
      params: { sort: '-rating,-reviewsCount', filter: 'isActive = true', perPage: limit },
    });
    return response.data.items.map(formatProduct);
  } catch (error) {
    console.error('Error fetching top rated products:', error.message);
    return [];
  }
}

async function getBestSellingProducts(limit = 4) {
  try {
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/products/records`, {
      params: { sort: '-reviewsCount,-rating', filter: 'isActive = true', perPage: limit },
    });
    return response.data.items.map(formatProduct);
  } catch (error) {
    console.error('Error fetching best selling products:', error.message);
    return [];
  }
}

async function getProductsByCategory(category, limit = 4) {
  try {
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/products/records`, {
      params: { sort: '-rating', filter: `category = "${category}" && isActive = true`, perPage: limit },
    });
    return response.data.items.map(formatProduct);
  } catch (error) {
    console.error('Error fetching products by category:', error.message);
    return [];
  }
}

async function getBanners() {
  try {
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/banners/records`, {
      params: { filter: 'isActive = true' },
    });
    return response.data.items.map(formatBanner);
  } catch (error) {
    console.error('Error fetching banners from PocketBase:', error.message);
    return [];
  }
}

async function getOrderById(orderId) {
  try {
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/orders/records/${orderId}`);
    return formatOrder(response.data);
  } catch (error) {
    console.error('Error fetching order from PocketBase:', error.message);
    return null;
  }
}

/**
 * Get full order tracking info (with new shipping fields)
 */
async function getOrderTracking(orderId) {
  try {
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/orders/records/${orderId}`);
    const record = response.data;

    // Build timeline from order timestamps and status
    const timeline = buildTimeline(record);

    return {
      orderId: record.id,
      status: (record.status || 'Pending').toLowerCase(),
      buyerName: record.buyerName || '',
      buyerPhone: record.buyerPhone || '',
      shippingAddress: record.shippingAddress || '',
      totalAmount: record.totalAmount || 0,
      shippingFee: record.shippingFee || 0,
      discount: record.discount || 0,
      paymentMethod: record.paymentMethod || '',
      courierName: record.courierName || 'Kartara Instant',
      courierService: record.courierService || 'Reguler',
      courierEta: record.courierEta || '1-3 hari',
      trackingNumber: record.trackingNumber || `KTR-${record.id.substring(0, 8).toUpperCase()}`,
      postalCode: record.postalCode || '',
      destinationCity: record.destinationCity || '',
      courierProgress: record.courierProgress || 0.3,
      courierLatitude: record.courierLatitude || null,
      courierLongitude: record.courierLongitude || null,
      trackingMilestones: record.trackingMilestones || null,
      created: record.created,
      updated: record.updated,
      paid_at: record.paid_at || null,
      timeline,
    };
  } catch (error) {
    console.error('Error fetching order tracking from PocketBase:', error.message);
    return null;
  }
}

/**
 * Build dynamic timeline based on order status and timestamps
 */
function buildTimeline(record) {
  const status = (record.status || 'Pending').toLowerCase();
  const createdAt = record.created ? new Date(record.created).toLocaleString('id-ID', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';
  const updatedAt = record.updated ? new Date(record.updated).toLocaleString('id-ID', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';
  const paidAt = record.paid_at ? new Date(record.paid_at).toLocaleString('id-ID', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';

  const isCancelled = status === 'cancelled' || status === 'dibatalkan';
  const isPaid = ['paid', 'diproses', 'processing', 'dikirim', 'shipped', 'selesai', 'completed'].includes(status);
  const isProcessing = ['diproses', 'processing', 'dikirim', 'shipped', 'selesai', 'completed'].includes(status);
  const isShipped = ['dikirim', 'shipped', 'selesai', 'completed'].includes(status);
  const isCompleted = status === 'selesai' || status === 'completed';

  if (isCancelled) {
    return [
      { title: 'Pesanan Dibatalkan', description: 'Pesanan ini telah dibatalkan.', timestamp: updatedAt, isCompleted: true, isActive: true },
      { title: 'Pesanan Dibuat', description: 'Invoice berhasil dibuat.', timestamp: createdAt, isCompleted: true, isActive: false },
    ];
  }

  return [
    {
      title: 'Pesanan Selesai',
      description: 'Paket telah diterima dengan baik. Terima kasih!',
      timestamp: isCompleted ? updatedAt : '',
      isCompleted,
      isActive: isCompleted,
    },
    {
      title: 'Pesanan Dikirim',
      description: `Kurir ${record.courierName || 'Kartara'} sedang mengantarkan paket Anda.`,
      timestamp: isShipped ? (isCompleted ? '' : updatedAt) : '',
      isCompleted: isShipped,
      isActive: isShipped && !isCompleted,
    },
    {
      title: 'Pesanan Diproses',
      description: 'Penjual sedang menyiapkan & mengemas kerupuk Anda.',
      timestamp: isProcessing ? (isShipped ? '' : updatedAt) : '',
      isCompleted: isProcessing,
      isActive: isProcessing && !isShipped,
    },
    {
      title: 'Pembayaran Sukses',
      description: 'Pembayaran dikonfirmasi. Menunggu proses penjual.',
      timestamp: paidAt || (isPaid ? updatedAt : ''),
      isCompleted: isPaid,
      isActive: isPaid && !isProcessing,
    },
    {
      title: 'Pesanan Dibuat',
      description: 'Invoice berhasil dibuat. Menunggu pembayaran.',
      timestamp: createdAt,
      isCompleted: true,
      isActive: status === 'pending',
    },
  ];
}

/**
 * Update courier location and progress in PocketBase
 */
async function updateOrderCourierLocation(orderId, lat, lng, progress) {
  try {
    await axios.patch(`${POCKETBASE_URL}/api/collections/orders/records/${orderId}`, {
      courierLatitude: lat,
      courierLongitude: lng,
      courierProgress: progress,
    });
    return true;
  } catch (error) {
    console.error('Error updating courier location:', error.message);
    return false;
  }
}

/**
 * Update order status in PocketBase
 */
async function updateOrderStatus(orderId, newStatus) {
  try {
    // Map English status to PocketBase Select values
    const statusMap = {
      'pending': 'Pending',
      'paid': 'Pending',       // Keep pending until admin processes
      'processing': 'Diproses',
      'diproses': 'Diproses',
      'shipped': 'Dikirim',
      'dikirim': 'Dikirim',
      'completed': 'Selesai',
      'selesai': 'Selesai',
    };
    const pbStatus = statusMap[newStatus.toLowerCase()] || 'Pending';
    await axios.patch(`${POCKETBASE_URL}/api/collections/orders/records/${orderId}`, {
      status: pbStatus,
      courierProgress: newStatus === 'completed' || newStatus === 'selesai' ? 1.0 : undefined,
    });
    return true;
  } catch (error) {
    console.error('Error updating order status:', error.message);
    return false;
  }
}

/**
 * Get orders by buyer phone (since no user relation in orders)
 */
async function getOrdersByBuyer(buyerPhone) {
  try {
    if (!buyerPhone || buyerPhone === 'guest') return [];
    let filter = `buyerPhone = "${buyerPhone}"`;
    if (/^\+?[0-9]+$/.test(buyerPhone)) {
      const cleanPhone = buyerPhone.replace(/^\+?62/, '').replace(/^0/, '');
      filter = `buyerPhone = "0${cleanPhone}" || buyerPhone = "+62${cleanPhone}" || buyerPhone = "${buyerPhone}"`;
    }
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/orders/records`, {
      params: {
        filter: filter,
        sort: '-created',
        perPage: 5,
      },
    });
    return (response.data.items || []).map(formatOrder);
  } catch (error) {
    console.error('Error fetching orders by buyer:', error.message);
    return [];
  }
}

/**
 * Get latest order - tries by phone, falls back to most recent
 */
async function getLatestOrder(userId) {
  try {
    let filter = '';
    if (userId && userId !== 'guest') {
      if (/^\+?[0-9]+$/.test(userId)) {
        const cleanPhone = userId.replace(/^\+?62/, '').replace(/^0/, '');
        filter = `buyerId = "${userId}" || buyerPhone = "0${cleanPhone}" || buyerPhone = "+62${cleanPhone}" || buyerPhone = "${userId}"`;
      } else {
        filter = `buyerId = "${userId}" || buyerPhone = "${userId}"`;
      }
    }

    const params = {
      sort: '-created',
      perPage: 1,
    };
    if (filter) params.filter = filter;

    const response = await axios.get(`${POCKETBASE_URL}/api/collections/orders/records`, { params });
    const items = response.data.items || [];
    if (items.length > 0) {
      return formatOrder(items[0]);
    }
    
    if (filter) {
      return null;
    }
    
    // Fallback: get absolute latest order (only for guest or unfiltered requests)
    const fallback = await axios.get(`${POCKETBASE_URL}/api/collections/orders/records`, {
      params: { sort: '-created', perPage: 1 },
    });
    const fallbackItems = fallback.data.items || [];
    return fallbackItems.length > 0 ? formatOrder(fallbackItems[0]) : null;
  } catch (error) {
    console.error('Error fetching latest order:', error.message);
    return null;
  }
}

async function getUserByPhoneOrId(userId) {
  try {
    if (!userId || userId === 'guest') return null;
    let filter = `id = "${userId}" || email = "${userId}"`;
    if (/^\+?[0-9]+$/.test(userId)) {
      const cleanPhone = userId.replace(/^\+?62/, '').replace(/^0/, '');
      filter += ` || phone = "0${cleanPhone}" || phone = "+62${cleanPhone}" || phone = "${userId}"`;
    } else {
      filter += ` || phone = "${userId}"`;
    }
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/users/records`, {
      params: {
        filter: filter,
        perPage: 1,
      },
    });
    const items = response.data.items || [];
    return items.length > 0 ? items[0] : null;
  } catch (error) {
    console.error('Error fetching user by phone or id:', error.message);
    return null;
  }
}

// ── Formatters ──────────────────────────────────────────────────────────────

function formatProduct(record) {
  const images = record.images || [];
  let imageUrl = 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&w=400&q=80';
  if (images.length > 0) {
    imageUrl = `${POCKETBASE_URL}/api/files/products/${record.id}/${images[0]}`;
  } else if (record.imageUrl) {
    imageUrl = record.imageUrl;
  }
  return {
    id: record.id,
    name: record.name || '',
    sellerName: record.sellerName || '',
    price: record.price || 0,
    originalPrice: record.originalPrice || 0,
    imageUrl,
    category: record.category || 'Udang',
    rating: record.rating || 4.8,
    reviewsCount: record.reviewsCount || 0,
    weight: record.weight || 250,
    description: record.description || '',
    stock: record.stock || 0,
    characteristics: record.characteristics || [],
  };
}

function formatBanner(record) {
  return {
    id: record.id,
    title: record.title || '',
    subtitle: record.subtitle || '',
    image: record.image || '',
    isActive: record.isActive || false,
  };
}

function formatOrder(record) {
  return {
    id: record.id,
    status: record.status || 'Pending',
    totalAmount: record.totalAmount || 0,
    shippingFee: record.shippingFee || 0,
    discount: record.discount || 0,
    buyerName: record.buyerName || '',
    buyerPhone: record.buyerPhone || '',
    shippingAddress: record.shippingAddress || '',
    paymentMethod: record.paymentMethod || '',
    courierName: record.courierName || '',
    courierService: record.courierService || '',
    courierEta: record.courierEta || '',
    trackingNumber: record.trackingNumber || `KTR-${record.id.substring(0, 8).toUpperCase()}`,
    postalCode: record.postalCode || '',
    destinationCity: record.destinationCity || '',
    courierProgress: record.courierProgress || 0,
    courierLatitude: record.courierLatitude || null,
    courierLongitude: record.courierLongitude || null,
    created: record.created,
    updated: record.updated,
    paid_at: record.paid_at || null,
  };
}

module.exports = {
  getProducts,
  getTopRatedProducts,
  getBestSellingProducts,
  getProductsByCategory,
  getBanners,
  getOrderById,
  getOrderTracking,
  getOrdersByBuyer,
  updateOrderCourierLocation,
  updateOrderStatus,
  getLatestOrder,
  getUserByPhoneOrId,
};
