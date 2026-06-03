const express = require('express');
const router = express.Router();
const pocketbaseService = require('../services/pocketbaseService');

// Koordinat asal UMKM Hub Kartara, Jepara
const ORIGIN = { lat: -6.5888, lng: 110.6686 };

/**
 * GET /api/tracking/:orderId
 * Info lengkap tracking pesanan dari PocketBase
 */
router.get('/:orderId', async (req, res) => {
  try {
    const { orderId } = req.params;
    console.log(`📦 [Tracking] Fetch tracking untuk order: ${orderId}`);

    const tracking = await pocketbaseService.getOrderTracking(orderId);

    if (!tracking) {
      return res.status(404).json({
        success: false,
        error: `Pesanan ${orderId} tidak ditemukan`,
      });
    }

    console.log(`✅ [Tracking] Status: ${tracking.status}, Kurir: ${tracking.courierName}`);

    res.json({
      success: true,
      tracking,
    });
  } catch (error) {
    console.error('❌ [Tracking] Error:', error);
    res.status(500).json({ success: false, error: 'Internal Server Error', message: error.message });
  }
});

/**
 * GET /api/tracking/:orderId/courier-location
 * Posisi kurir terkini (polling setiap 5 detik dari Flutter)
 */
router.get('/:orderId/courier-location', async (req, res) => {
  try {
    const { orderId } = req.params;
    const tracking = await pocketbaseService.getOrderTracking(orderId);

    if (!tracking) {
      return res.status(404).json({ success: false, error: 'Pesanan tidak ditemukan' });
    }

    const status = tracking.status;

    // Jika completed → kurir sudah di tujuan
    if (status === 'selesai' || status === 'completed') {
      return res.json({
        success: true,
        location: {
          lat: null,   // Flutter akan gunakan buyer location
          lng: null,
          progress: 1.0,
          source: 'completed',
          status,
        },
      });
    }

    // Jika ada koordinat real di PocketBase
    if (tracking.courierLatitude && tracking.courierLongitude) {
      return res.json({
        success: true,
        location: {
          lat: tracking.courierLatitude,
          lng: tracking.courierLongitude,
          progress: tracking.courierProgress || 0.5,
          source: 'real',
          status,
          updatedAt: tracking.updated,
        },
      });
    }

    // Simulasi: interpolasi berdasarkan progress antara Jepara (origin) dan estimasi tujuan
    const progress = tracking.courierProgress || 0.3;

    // Estimasi koordinat tujuan dari kode pos atau default Semarang
    const destCoords = getDestinationCoords(tracking.postalCode, tracking.destinationCity);

    // Interpolasi posisi kurir
    const courierLat = ORIGIN.lat + (destCoords.lat - ORIGIN.lat) * progress;
    const courierLng = ORIGIN.lng + (destCoords.lng - ORIGIN.lng) * progress;

    // Simulasi pergerakan: tingkatkan progress 5% setiap kali dicek (max 1.0)
    if (status === 'dikirim' || status === 'shipped') {
      const newProgress = Math.min(progress + 0.05, 0.95);
      // Update async (fire and forget)
      pocketbaseService.updateOrderCourierLocation(orderId, courierLat, courierLng, newProgress).catch(() => {});
    }

    res.json({
      success: true,
      location: {
        lat: courierLat,
        lng: courierLng,
        progress,
        source: 'simulated',
        status,
        destination: destCoords,
      },
    });
  } catch (error) {
    console.error('❌ [Tracking/Location] Error:', error);
    res.status(500).json({ success: false, error: 'Internal Server Error' });
  }
});

/**
 * POST /api/tracking/:orderId/complete
 * Tandai pesanan selesai
 */
router.post('/:orderId/complete', async (req, res) => {
  try {
    const { orderId } = req.params;
    console.log(`✅ [Tracking] Menandai pesanan selesai: ${orderId}`);

    const ok = await pocketbaseService.updateOrderStatus(orderId, 'selesai');

    if (ok) {
      res.json({ success: true, message: 'Pesanan ditandai selesai.' });
    } else {
      res.status(500).json({ success: false, error: 'Gagal update status.' });
    }
  } catch (error) {
    console.error('❌ [Tracking/Complete] Error:', error);
    res.status(500).json({ success: false, error: 'Internal Server Error' });
  }
});

/**
 * PATCH /api/tracking/:orderId/update-location
 * Update posisi kurir (dipanggil oleh sistem kurir / admin)
 */
router.patch('/:orderId/update-location', async (req, res) => {
  try {
    const { orderId } = req.params;
    const { lat, lng, progress } = req.body;

    if (!lat || !lng) {
      return res.status(400).json({ success: false, error: 'lat dan lng wajib diisi' });
    }

    await pocketbaseService.updateOrderCourierLocation(orderId, lat, lng, progress || 0.5);

    res.json({ success: true, message: 'Lokasi kurir diperbarui.' });
  } catch (error) {
    console.error('❌ [Tracking/UpdateLocation] Error:', error);
    res.status(500).json({ success: false, error: 'Internal Server Error' });
  }
});

// ── Helper: estimasi koordinat dari kode pos/kota ────────────────────────────

const CITY_COORDS = {
  'semarang': { lat: -6.9947, lng: 110.4100 },
  'jakarta': { lat: -6.2088, lng: 106.8456 },
  'surabaya': { lat: -7.2575, lng: 112.7521 },
  'bandung': { lat: -6.9175, lng: 107.6191 },
  'yogyakarta': { lat: -7.7956, lng: 110.3695 },
  'solo': { lat: -7.5697, lng: 110.8315 },
  'malang': { lat: -7.9825, lng: 112.6308 },
  'denpasar': { lat: -8.6705, lng: 115.2126 },
  'medan': { lat: 3.5896, lng: 98.6739 },
  'makassar': { lat: -5.1477, lng: 119.4327 },
};

const POSTAL_COORDS = {
  '59411': { lat: -6.5888, lng: 110.6686 },
  '50111': { lat: -6.9947, lng: 110.4100 },
  '10110': { lat: -6.1744, lng: 106.8227 },
  '60111': { lat: -7.2575, lng: 112.7521 },
  '40111': { lat: -6.9175, lng: 107.6191 },
  '55111': { lat: -7.7956, lng: 110.3695 },
};

function getDestinationCoords(postalCode, destinationCity) {
  // Try postal code first
  if (postalCode && POSTAL_COORDS[postalCode]) {
    return POSTAL_COORDS[postalCode];
  }
  // Try prefix match
  if (postalCode) {
    const prefix = postalCode.substring(0, 3);
    const match = Object.keys(POSTAL_COORDS).find(k => k.startsWith(prefix));
    if (match) return POSTAL_COORDS[match];
  }
  // Try city name
  if (destinationCity) {
    const cityLower = destinationCity.toLowerCase();
    const cityKey = Object.keys(CITY_COORDS).find(k => cityLower.includes(k));
    if (cityKey) return CITY_COORDS[cityKey];
  }
  // Default: Semarang (dekat Jepara)
  return { lat: -6.9947, lng: 110.4100 };
}

module.exports = router;
