const express = require('express');
const router = express.Router();
const axios = require('axios');

/**
 * Database koordinat kode pos Indonesia (sampling representatif)
 * Format: { kodePos: { lat, lng, city, province } }
 */
const POSTAL_CODE_DB = {
  // === JAWA TENGAH ===
  '59411': { lat: -6.5888, lng: 110.6686, city: 'Jepara', province: 'Jawa Tengah' }, // Origin UMKM Hub
  '59412': { lat: -6.5831, lng: 110.6523, city: 'Jepara', province: 'Jawa Tengah' },
  '59413': { lat: -6.6012, lng: 110.6791, city: 'Jepara', province: 'Jawa Tengah' },
  '59421': { lat: -6.4917, lng: 110.5833, city: 'Mayong', province: 'Jawa Tengah' },
  '59431': { lat: -6.3921, lng: 110.5133, city: 'Welahan', province: 'Jawa Tengah' },
  '59461': { lat: -6.7183, lng: 110.8383, city: 'Demak', province: 'Jawa Tengah' },
  '50111': { lat: -6.9947, lng: 110.4100, city: 'Semarang', province: 'Jawa Tengah' },
  '50112': { lat: -6.9824, lng: 110.4150, city: 'Semarang', province: 'Jawa Tengah' },
  '50132': { lat: -7.0051, lng: 110.4381, city: 'Semarang Timur', province: 'Jawa Tengah' },
  '57111': { lat: -7.5697, lng: 110.8315, city: 'Solo', province: 'Jawa Tengah' },
  '55111': { lat: -7.7956, lng: 110.3695, city: 'Yogyakarta', province: 'DI Yogyakarta' },
  '56111': { lat: -7.4044, lng: 109.6832, city: 'Purwokerto', province: 'Jawa Tengah' },
  '59141': { lat: -6.7041, lng: 110.9211, city: 'Kudus', province: 'Jawa Tengah' },
  '59311': { lat: -6.8811, lng: 111.3312, city: 'Blora', province: 'Jawa Tengah' },
  '58111': { lat: -7.9825, lng: 111.3278, city: 'Magelang', province: 'Jawa Tengah' },
  // === JAWA BARAT ===
  '40111': { lat: -6.9175, lng: 107.6191, city: 'Bandung', province: 'Jawa Barat' },
  '43111': { lat: -6.8374, lng: 107.0793, city: 'Bekasi', province: 'Jawa Barat' },
  '16111': { lat: -6.5971, lng: 106.8060, city: 'Bogor', province: 'Jawa Barat' },
  '41151': { lat: -6.7689, lng: 108.5507, city: 'Cirebon', province: 'Jawa Barat' },
  '15111': { lat: -6.2297, lng: 106.6894, city: 'Tangerang', province: 'Banten' },
  // === DKI JAKARTA ===
  '10110': { lat: -6.1744, lng: 106.8227, city: 'Jakarta Pusat', province: 'DKI Jakarta' },
  '10120': { lat: -6.1767, lng: 106.8249, city: 'Gambir', province: 'DKI Jakarta' },
  '12110': { lat: -6.2297, lng: 106.8219, city: 'Jakarta Selatan', province: 'DKI Jakarta' },
  '13110': { lat: -6.2148, lng: 106.8650, city: 'Jakarta Timur', province: 'DKI Jakarta' },
  '14110': { lat: -6.1374, lng: 106.8186, city: 'Jakarta Utara', province: 'DKI Jakarta' },
  '11110': { lat: -6.1674, lng: 106.7638, city: 'Jakarta Barat', province: 'DKI Jakarta' },
  // === JAWA TIMUR ===
  '60111': { lat: -7.2575, lng: 112.7521, city: 'Surabaya', province: 'Jawa Timur' },
  '65111': { lat: -7.9825, lng: 112.6308, city: 'Malang', province: 'Jawa Timur' },
  '64111': { lat: -7.7501, lng: 112.0288, city: 'Kediri', province: 'Jawa Timur' },
  '61111': { lat: -7.5441, lng: 112.2255, city: 'Mojokerto', province: 'Jawa Timur' },
  // === BALI ===
  '80111': { lat: -8.6705, lng: 115.2126, city: 'Denpasar', province: 'Bali' },
  '80117': { lat: -8.5069, lng: 115.2625, city: 'Singaraja', province: 'Bali' },
  // === SUMATERA ===
  '10000': { lat: 3.5896, lng: 98.6739, city: 'Medan', province: 'Sumatera Utara' },
  '29111': { lat: 0.5071, lng: 101.4478, city: 'Pekanbaru', province: 'Riau' },
  '30111': { lat: -2.9909, lng: 104.7566, city: 'Palembang', province: 'Sumatera Selatan' },
  '35111': { lat: -5.4295, lng: 105.2614, city: 'Bandar Lampung', province: 'Lampung' },
  // === KALIMANTAN ===
  '70111': { lat: -3.3194, lng: 114.5908, city: 'Banjarmasin', province: 'Kalimantan Selatan' },
  '76111': { lat: -0.5022, lng: 117.1536, city: 'Samarinda', province: 'Kalimantan Timur' },
  '78111': { lat: -0.0263, lng: 109.3425, city: 'Pontianak', province: 'Kalimantan Barat' },
  // === SULAWESI ===
  '90111': { lat: -5.1477, lng: 119.4327, city: 'Makassar', province: 'Sulawesi Selatan' },
  '94111': { lat: -0.8917, lng: 119.8707, city: 'Palu', province: 'Sulawesi Tengah' },
  '95111': { lat: 1.4748, lng: 124.8421, city: 'Manado', province: 'Sulawesi Utara' },
  // === PAPUA ===
  '99111': { lat: -2.5337, lng: 140.7181, city: 'Jayapura', province: 'Papua' },
  '98111': { lat: -3.9870, lng: 136.6180, city: 'Timika', province: 'Papua' },
};

// Koordinat asal UMKM Hub Kartara, Jepara
const ORIGIN = { lat: -6.5888, lng: 110.6686, city: 'Jepara' };

/**
 * Menghitung jarak antara dua koordinat menggunakan Haversine Formula (km)
 */
function haversineDistance(lat1, lng1, lat2, lng2) {
  const R = 6371; // Jari-jari bumi (km)
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
    Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Mencari data kode pos, termasuk prefix matching jika tidak ditemukan exact match
 */
function findPostalCode(postalCode) {
  const cleaned = postalCode.toString().trim();

  // Exact match
  if (POSTAL_CODE_DB[cleaned]) return POSTAL_CODE_DB[cleaned];

  // Prefix match: cari kode pos 5 digit yang paling mirip
  const prefix4 = cleaned.substring(0, 4);
  const prefix3 = cleaned.substring(0, 3);
  const prefix2 = cleaned.substring(0, 2);

  for (const key of Object.keys(POSTAL_CODE_DB)) {
    if (key.startsWith(prefix4)) return POSTAL_CODE_DB[key];
  }
  for (const key of Object.keys(POSTAL_CODE_DB)) {
    if (key.startsWith(prefix3)) return POSTAL_CODE_DB[key];
  }
  for (const key of Object.keys(POSTAL_CODE_DB)) {
    if (key.startsWith(prefix2)) return POSTAL_CODE_DB[key];
  }

  return null;
}

/**
 * Menghitung tarif ongkir berdasarkan jarak dan berat
 * Rumus: tarif dasar + (jarak x tarif per km) + (kelebihan berat x biaya berat)
 */
function calculateShippingFees(distanceKm, weightGram) {
  const weightKg = weightGram / 1000;

  // Klasifikasi zona berdasarkan jarak
  let zone;
  if (distanceKm <= 30)        zone = 'lokal';    // Dalam kab. Jepara
  else if (distanceKm <= 150)  zone = 'regional'; // Jawa Tengah / sekitar
  else if (distanceKm <= 500)  zone = 'antarpulau_dekat'; // Jawa-Jawa
  else if (distanceKm <= 1500) zone = 'antarpulau'; // Jawa ke luar Jawa
  else                         zone = 'jauh';     // Jarak sangat jauh (Papua, dll)

  const zoneConfig = {
    lokal:             { baseFee: 7000,  perKm: 150,  label: 'Lokal Jepara' },
    regional:          { baseFee: 12000, perKm: 120,  label: 'Regional Jawa Tengah' },
    antarpulau_dekat:  { baseFee: 18000, perKm: 90,   label: 'Antar-Kota Jawa' },
    antarpulau:        { baseFee: 28000, perKm: 70,   label: 'Luar Pulau Jawa' },
    jauh:              { baseFee: 45000, perKm: 60,   label: 'Jarak Jauh' },
  };

  const cfg = zoneConfig[zone];
  const base = cfg.baseFee + Math.round(distanceKm * cfg.perKm);
  const weightSurcharge = weightKg > 1 ? Math.round((weightKg - 1) * 2000) : 0;

  // Tarif tiap kurir (dengan karakter masing-masing)
  const jnt   = Math.round((base + weightSurcharge) * 0.95 / 500) * 500;  // J&T paling murah
  const jne   = Math.round((base + weightSurcharge) * 1.05 / 500) * 500;  // JNE sedikit lebih mahal
  const instant = zone === 'lokal'
    ? Math.round((base + weightSurcharge) * 0.8 / 500) * 500   // Instant lebih murah jika lokal
    : null; // Instant tidak tersedia untuk jarak jauh

  const etaJnt   = zone === 'lokal' ? '1 hari' : zone === 'regional' ? '2-3 hari' : zone === 'antarpulau_dekat' ? '3-4 hari' : '5-7 hari';
  const etaJne   = zone === 'lokal' ? '1 hari' : zone === 'regional' ? '1-2 hari' : zone === 'antarpulau_dekat' ? '2-3 hari' : '4-6 hari';
  const etaInstant = '1-3 jam';

  return { zone, zoneLabel: cfg.label, jnt, jne, instant, etaJnt, etaJne, etaInstant };
}

/**
 * Sistem pemilihan kurir otomatis berdasarkan zona & performa
 * Kurir dipilih oleh sistem secara cerdas (bukan user yang memilih manual)
 */
function autoSelectCourier(fees, zone, weightGram) {
  const couriers = [];

  // J&T Express - selalu tersedia, termurah
  couriers.push({
    name: 'J&T Express',
    fee: fees.jnt,
    desc: `Reguler · Estimasi ${fees.etaJnt}`,
    eta: fees.etaJnt,
    recommended: zone !== 'lokal', // recommended untuk jarak menengah-jauh
    tag: zone === 'lokal' ? null : '💰 Termurah',
  });

  // JNE REG - lebih cepat, sedikit lebih mahal
  couriers.push({
    name: 'JNE Reguler',
    fee: fees.jne,
    desc: `Reguler · Estimasi ${fees.etaJne}`,
    eta: fees.etaJne,
    recommended: zone === 'regional' || zone === 'antarpulau_dekat',
    tag: (zone === 'regional' || zone === 'antarpulau_dekat') ? '⚡ Terpopuler' : null,
  });

  // Kartara Instant - hanya tersedia untuk zona lokal
  if (fees.instant !== null) {
    couriers.push({
      name: 'Kartara Instant',
      fee: fees.instant,
      desc: `Ekspres · Estimasi ${fees.etaInstant}`,
      eta: fees.etaInstant,
      recommended: zone === 'lokal',
      tag: zone === 'lokal' ? '🚀 Terbaik' : null,
    });
  }

  // Urutkan: yang recommended naik ke atas, sisanya urut berdasarkan harga
  couriers.sort((a, b) => {
    if (a.recommended && !b.recommended) return -1;
    if (!a.recommended && b.recommended) return 1;
    return a.fee - b.fee;
  });

  return couriers;
}

/**
 * POST /api/shipping/calculate
 * Hitung ongkir berdasarkan kode pos tujuan dengan kalkulasi jarak nyata
 */
router.post('/calculate', async (req, res) => {
  try {
    const { destinationAddress, postalCode, totalWeight = 1000 } = req.body;

    if (!postalCode) {
      return res.status(400).json({
        success: false,
        error: 'Kode pos tujuan wajib diisi',
      });
    }

    console.log(`🚚 [Shipping] Menghitung ongkir ke kode pos: ${postalCode}, berat: ${totalWeight}g`);

    const biteshipKey = process.env.BITESHIP_API_KEY;
    const isMock = !biteshipKey || biteshipKey.includes('mock') || biteshipKey.includes('test');

    // ——— Coba Biteship API jika API Key asli tersedia ———
    if (!isMock) {
      try {
        const mapsRes = await axios.get(
          `https://api.biteship.com/v1/maps/areas?countries=ID&input=${postalCode}`,
          { headers: { Authorization: `Bearer ${biteshipKey}` }, timeout: 8000 }
        );

        const areas = mapsRes.data.areas || [];
        if (areas.length > 0) {
          const destAreaId = areas[0].id;
          const originAreaId = 'IDR332010100'; // Jepara

          const ratesRes = await axios.post(
            'https://api.biteship.com/v1/rates/couriers',
            {
              origin_area_id: originAreaId,
              destination_area_id: destAreaId,
              couriers: 'jne,jnt,sicepat,anteraja',
              items: [{ name: 'Kerupuk Kartara', description: 'Paket makanan', value: 50000, weight: totalWeight, quantity: 1 }],
            },
            {
              headers: { Authorization: `Bearer ${biteshipKey}`, 'Content-Type': 'application/json' },
              timeout: 10000,
            }
          );

          const pricing = ratesRes.data.pricing || [];
          if (pricing.length > 0) {
            const biteshipCouriers = pricing.map(p => ({
              name: `${p.courier_name} ${p.courier_service}`,
              fee: parseFloat(p.price),
              desc: `${p.courier_desc || ''} · Estimasi ${p.duration?.en || '2-3 hari'}`,
              eta: p.duration?.en || '2-3 hari',
              recommended: false,
              tag: null,
            }));

            // Tandai yang termurah sebagai recommended
            if (biteshipCouriers.length > 0) {
              biteshipCouriers.sort((a, b) => a.fee - b.fee);
              biteshipCouriers[0].recommended = true;
              biteshipCouriers[0].tag = '💰 Termurah';
            }

            console.log(`✅ [Biteship] ${biteshipCouriers.length} opsi kurir ditemukan`);
            return res.json({
              success: true,
              source: 'biteship_api',
              postalCode,
              couriers: biteshipCouriers,
            });
          }
        }
      } catch (biteshipErr) {
        console.warn('⚠️ [Biteship] API gagal, fallback ke kalkulasi lokal:', biteshipErr.message);
      }
    }

    // ——— Fallback: Kalkulasi Cerdas Berbasis Kode Pos + Jarak ———
    const destInfo = findPostalCode(postalCode);

    let distanceKm;
    let destinationLabel;

    if (destInfo) {
      distanceKm = haversineDistance(ORIGIN.lat, ORIGIN.lng, destInfo.lat, destInfo.lng);
      destinationLabel = `${destInfo.city}, ${destInfo.province}`;
      console.log(`📍 [Shipping] Kode pos ${postalCode} → ${destinationLabel}, jarak: ${distanceKm.toFixed(1)} km`);
    } else {
      // Jika kode pos tidak dikenali, estimasi dari prefix
      const prefix = postalCode.toString()[0];
      const estimatedDistances = { '1': 600, '2': 650, '3': 400, '4': 300, '5': 200, '6': 450, '7': 900, '8': 750, '9': 2400 };
      distanceKm = estimatedDistances[prefix] || 500;
      destinationLabel = `Wilayah tidak dikenali (estimasi)`;
      console.log(`⚠️ [Shipping] Kode pos ${postalCode} tidak ditemukan, estimasi jarak: ${distanceKm} km`);
    }

    const fees = calculateShippingFees(distanceKm, totalWeight);
    const couriers = autoSelectCourier(fees, fees.zone, totalWeight);

    console.log(`📦 [Shipping] Zona: ${fees.zoneLabel}, ${couriers.length} kurir tersedia`);

    res.json({
      success: true,
      source: 'smart_calculation',
      postalCode,
      destination: destinationLabel,
      distanceKm: Math.round(distanceKm),
      zone: fees.zone,
      zoneLabel: fees.zoneLabel,
      couriers,
    });

  } catch (error) {
    console.error('❌ [Shipping] Error:', error);
    res.status(500).json({ success: false, error: 'Internal Server Error', message: error.message });
  }
});

/**
 * GET /api/shipping/postal-info/:code
 * Info wilayah dari kode pos (untuk preview di Flutter)
 */
router.get('/postal-info/:code', (req, res) => {
  const { code } = req.params;
  const info = findPostalCode(code);

  if (!info) {
    return res.status(404).json({ success: false, error: `Kode pos ${code} tidak ditemukan` });
  }

  const distanceKm = haversineDistance(ORIGIN.lat, ORIGIN.lng, info.lat, info.lng);

  res.json({
    success: true,
    postalCode: code,
    city: info.city,
    province: info.province,
    distanceKm: Math.round(distanceKm),
    origin: ORIGIN.city,
  });
});

module.exports = router;
