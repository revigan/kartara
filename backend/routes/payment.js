const express = require('express');
const router = express.Router();
const axios = require('axios');
const pb = require('../config/pocketbase');

// ──────────────────────────────────────────────────────────────────────────────
// KlikQRIS Configuration
// ──────────────────────────────────────────────────────────────────────────────
const KLIKQRIS_BASE_URL = 'https://klikqris.com/api';
const KLIKQRIS_API_KEY  = process.env.KLIKQRIS_API_KEY;
const KLIKQRIS_MERCHANT_ID = process.env.KLIKQRIS_MERCHANT_ID;

// Shared axios headers for KlikQRIS API
function klikqrisHeaders() {
  return {
    'Content-Type': 'application/json',
    'x-api-key': KLIKQRIS_API_KEY,
    'id_merchant': KLIKQRIS_MERCHANT_ID,
  };
}

// ──────────────────────────────────────────────────────────────────────────────
// POST /api/create-transaction
// Buat QRIS dinamis baru via KlikQRIS
// ──────────────────────────────────────────────────────────────────────────────
router.post('/create-transaction', async (req, res) => {
  try {
    const { orderId, totalAmount, customerName, keterangan } = req.body;

    if (!orderId || !totalAmount) {
      return res.status(400).json({
        error: 'Missing required fields',
        required: ['orderId', 'totalAmount'],
      });
    }

    console.log(`📥 [KlikQRIS] Create transaction: order=${orderId}, amount=${totalAmount}`);

    const payload = {
      order_id:    orderId,
      id_merchant: KLIKQRIS_MERCHANT_ID,
      amount:      Math.round(totalAmount),
      keterangan:  keterangan || `Pembayaran Pesanan #${orderId}`,
    };

    const response = await axios.post(
      `${KLIKQRIS_BASE_URL}/qris/create`,
      payload,
      { headers: klikqrisHeaders() }
    );

    const data = response.data;

    if (!data.status) {
      console.error('❌ [KlikQRIS] API error:', data.message);
      return res.status(400).json({ error: data.message || 'KlikQRIS error' });
    }

    const txData = data.data;
    console.log(`✅ [KlikQRIS] Transaction created: order=${txData.order_id}, status=${txData.status}`);

    // Simpan signature ke snap_token agar bisa dipakai polling nanti
    try {
      await pb.collection('orders').update(orderId, {
        snap_token: txData.signature || '',
        payment_status: 'pending_payment',
      });
    } catch (pbErr) {
      console.log('PocketBase snap_token update skipped:', pbErr.message);
    }

    return res.json({
      success: true,
      order_id:    txData.order_id,
      qris_image:  txData.qris_image,   // base64 PNG — ditampilkan langsung di Flutter
      qris_url:    txData.qris_url,     // URL gambar alternatif
      total_amount: txData.total_amount,
      expired_at:  txData.expired_at,
      expired_menit: txData.expired_menit,
      signature:   txData.signature,
    });

  } catch (error) {
    console.error('❌ [KlikQRIS] create-transaction error:', error.response?.data || error.message);
    res.status(500).json({
      error: 'Failed to create QRIS transaction',
      message: error.response?.data?.message || error.message,
    });
  }
});

// ──────────────────────────────────────────────────────────────────────────────
// GET /api/payment-status/:orderId
// Cek status pembayaran dari KlikQRIS & PocketBase
// ──────────────────────────────────────────────────────────────────────────────
router.get('/payment-status/:orderId', async (req, res) => {
  const { orderId } = req.params;

  // 1. Cek PocketBase terlebih dahulu
  let orderData = null;
  let pbPaymentStatus = 'pending_payment';
  try {
    const order = await pb.collection('orders').getOne(orderId);
    pbPaymentStatus = order.payment_status || 'pending_payment';
    orderData = {
      payment_status: pbPaymentStatus,
      order_status: order.status,
      paid_at: order.paid_at,
    };
    // Jika PocketBase sudah menandai paid → langsung return tanpa tanya KlikQRIS
    if (pbPaymentStatus === 'paid') {
      return res.json({
        success: true,
        order_id: orderId,
        transaction_status: 'settlement',
        order: orderData,
      });
    }
  } catch (pbError) {
    console.log(`PocketBase lookup failed for ${orderId}:`, pbError.message);
  }

  // 2. Tanya KlikQRIS
  let kqStatus = 'PENDING';
  try {
    const kqRes = await axios.get(
      `${KLIKQRIS_BASE_URL}/qris/status/${orderId}`,
      { headers: klikqrisHeaders() }
    );
    kqStatus = kqRes.data?.data?.status || 'PENDING';
    console.log(`🔍 [KlikQRIS] Status for ${orderId}: ${kqStatus}`);

    // Sinkronkan ke PocketBase jika sudah PAID
    if (kqStatus === 'SUCCESS' || kqStatus === 'PAID') {
      try {
        await pb.collection('orders').update(orderId, {
          payment_status: 'paid',
          status: 'Diproses',
          paid_at: new Date().toISOString(),
        });
        orderData = { ...orderData, payment_status: 'paid', order_status: 'Diproses' };
      } catch (e) {
        console.error('PocketBase update error:', e.message);
      }
    }
  } catch (kqError) {
    console.log(`KlikQRIS status check failed for ${orderId}:`, kqError.message);
  }

  const isPaid = kqStatus === 'SUCCESS' || kqStatus === 'PAID';

  res.json({
    success: true,
    order_id: orderId,
    transaction_status: isPaid ? 'settlement' : kqStatus.toLowerCase(),
    order: orderData,
  });
});

// ──────────────────────────────────────────────────────────────────────────────
// POST /api/klikqris/webhook
// Terima notifikasi otomatis dari KlikQRIS saat status berubah PAID / EXPIRED
// ──────────────────────────────────────────────────────────────────────────────
router.post('/klikqris/webhook', async (req, res) => {
  try {
    const body = req.body;
    console.log('📥 [KlikQRIS] Webhook received:', JSON.stringify(body));

    const orderId = body.order_id || body.data?.order_id;
    const status  = (body.status  || body.data?.status || '').toUpperCase();

    if (!orderId) {
      return res.status(400).json({ error: 'Missing order_id' });
    }

    if (status === 'PAID' || status === 'SUCCESS') {
      await pb.collection('orders').update(orderId, {
        payment_status: 'paid',
        status: 'Diproses',
        paid_at: new Date().toISOString(),
      });
      console.log(`✅ [KlikQRIS] Order ${orderId} marked as PAID`);
    } else if (status === 'EXPIRED') {
      await pb.collection('orders').update(orderId, {
        payment_status: 'fail',
        status: 'Menunggu Pembayaran',
      });
      console.log(`⏰ [KlikQRIS] Order ${orderId} EXPIRED`);
    }

    res.json({ success: true });

  } catch (error) {
    console.error('❌ [KlikQRIS] Webhook error:', error.message);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

module.exports = router;
