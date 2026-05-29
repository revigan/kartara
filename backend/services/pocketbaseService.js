const axios = require('axios');

const POCKETBASE_URL = process.env.POCKETBASE_URL || 'http://127.0.0.1:8090';

/**
 * Get all products from PocketBase
 */
async function getProducts() {
  try {
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/products/records`, {
      params: {
        sort: '-created',
        filter: 'isActive = true',
      },
    });
    
    return response.data.items.map(formatProduct);
  } catch (error) {
    console.error('Error fetching products from PocketBase:', error.message);
    return [];
  }
}

/**
 * Get top rated products
 */
async function getTopRatedProducts(limit = 4) {
  try {
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/products/records`, {
      params: {
        sort: '-rating,-reviewsCount',
        filter: 'isActive = true',
        perPage: limit,
      },
    });
    
    return response.data.items.map(formatProduct);
  } catch (error) {
    console.error('Error fetching top rated products:', error.message);
    return [];
  }
}

/**
 * Get best selling products (by reviews count as proxy)
 */
async function getBestSellingProducts(limit = 4) {
  try {
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/products/records`, {
      params: {
        sort: '-reviewsCount,-rating',
        filter: 'isActive = true',
        perPage: limit,
      },
    });
    
    return response.data.items.map(formatProduct);
  } catch (error) {
    console.error('Error fetching best selling products:', error.message);
    return [];
  }
}

/**
 * Get products by category
 */
async function getProductsByCategory(category, limit = 4) {
  try {
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/products/records`, {
      params: {
        sort: '-rating',
        filter: `category = "${category}" && isActive = true`,
        perPage: limit,
      },
    });
    
    return response.data.items.map(formatProduct);
  } catch (error) {
    console.error('Error fetching products by category:', error.message);
    return [];
  }
}

/**
 * Get all banners
 */
async function getBanners() {
  try {
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/banners/records`, {
      params: {
        filter: 'isActive = true',
      },
    });
    
    return response.data.items.map(formatBanner);
  } catch (error) {
    console.error('Error fetching banners from PocketBase:', error.message);
    return [];
  }
}

/**
 * Get order by ID
 */
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
 * Format product data
 */
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
    imageUrl: imageUrl,
    category: record.category || 'Udang',
    rating: record.rating || 4.8,
    reviewsCount: record.reviewsCount || 0,
    weight: record.weight || 250,
    description: record.description || '',
    stock: record.stock || 0,
  };
}

/**
 * Format banner data
 */
function formatBanner(record) {
  return {
    id: record.id,
    title: record.title || '',
    subtitle: record.subtitle || '',
    image: record.image || '',
    isActive: record.isActive || false,
  };
}

/**
 * Format order data
 */
function formatOrder(record) {
  return {
    id: record.id,
    status: record.status || 'Pending',
    totalAmount: record.totalAmount || 0,
    buyerName: record.buyerName || '',
    buyerPhone: record.buyerPhone || '',
    shippingAddress: record.shippingAddress || '',
    paymentMethod: record.paymentMethod || '',
    created: record.created,
  };
}

/**
 * Get latest order for user
 */
async function getLatestOrder(userId) {
  try {
    const response = await axios.get(`${POCKETBASE_URL}/api/collections/orders/records`, {
      params: {
        filter: `user = "${userId}"`,
        sort: '-created',
        perPage: 1,
      },
    });
    const items = response.data.items || [];
    if (items.length > 0) {
      return formatOrder(items[0]);
    }
    return null;
  } catch (error) {
    console.error('Error fetching latest order:', error.message);
    return null;
  }
}

module.exports = {
  getProducts,
  getTopRatedProducts,
  getBestSellingProducts,
  getProductsByCategory,
  getBanners,
  getOrderById,
  getLatestOrder,
};
