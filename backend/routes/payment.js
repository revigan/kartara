const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const { snap, core } = require('../config/midtrans');
const pb = require('../config/pocketbase');

// Generate unique order code
function generateOrderCode() {
  const timestamp = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).substring(2, 6).toUpperCase();
  return `KRT-${timestamp}-${random}`;
}

// POST /api/create-transaction
// Create Midtrans Snap transaction
router.post('/create-transaction', async (req, res) => {
  try {
    console.log('📥 Received create-transaction request:', {
      orderId: req.body.orderId,
      totalAmount: req.body.totalAmount,
      customerName: req.body.customerName
    });

    const {
      orderId,
      totalAmount,
      customerName,
      customerEmail,
      customerPhone,
      paymentType,
      items
    } = req.body;

    // Validation
    if (!orderId || !totalAmount || !customerName || !customerEmail || !customerPhone) {
      console.log('❌ Validation failed: Missing required fields');
      return res.status(400).json({
        error: 'Missing required fields',
        required: ['orderId', 'totalAmount', 'customerName', 'customerEmail', 'customerPhone']
      });
    }

    const itemDetails = items || [
      {
        id: 'item-1',
        price: Math.round(totalAmount),
        quantity: 1,
        name: 'Pesanan Kartara'
      }
    ];

    // Hitung ulang total dari item_details
    const itemsTotal = itemDetails.reduce((sum, item) => {
      return sum + (Math.round(item.price) * item.quantity);
    }, 0);

    const grossAmount = Math.round(totalAmount);

    // Jika ada selisih (mis. karena diskon kupon), tambahkan item diskon
    if (itemsTotal !== grossAmount) {
      const discountAmount = itemsTotal - grossAmount;
      if (discountAmount > 0) {
        itemDetails.push({
          id: 'disc-1',
          price: -discountAmount,
          quantity: 1,
          name: 'Diskon Kupon'
        });
      } else {
        // jika gross > items, sesuaikan dengan ongkir
        itemDetails.push({
          id: 'fee-1',
          price: Math.abs(discountAmount),
          quantity: 1,
          name: 'Biaya Tambahan'
        });
      }
    }

    // Create a unique order ID for Midtrans to avoid "order_id has already been taken" error on retries
    const midtransOrderId = `${orderId}-${Date.now()}`;

    // Create transaction parameter
    const parameter = {
      transaction_details: {
        order_id: midtransOrderId,
        gross_amount: grossAmount
      },
      customer_details: {
        first_name: customerName,
        email: customerEmail,
        phone: customerPhone
      },
      item_details: itemDetails,
      callbacks: {
        finish: `${process.env.APP_URL || process.env.NGROK_URL}/api/success?order_id=${orderId}`,
        error: `${process.env.APP_URL || process.env.NGROK_URL}/api/failed?order_id=${orderId}`,
        pending: `${process.env.APP_URL || process.env.NGROK_URL}/api/pending?order_id=${orderId}`
      }
    };

    if (paymentType === 'e_wallet') {
      parameter.enabled_payments = ['gopay', 'shopeepay', 'qris'];
    } else if (paymentType === 'bank_transfer') {
      parameter.enabled_payments = ['bank_transfer', 'bca_va', 'bni_va', 'bri_va', 'permata_va', 'echannel'];
    }

    console.log('📤 Creating Midtrans transaction with parameter:', {
      order_id: parameter.transaction_details.order_id,
      gross_amount: parameter.transaction_details.gross_amount,
      enabled_payments: parameter.enabled_payments
    });

    // Create Snap transaction
    const transaction = await snap.createTransaction(parameter);

    console.log('✅ Midtrans transaction created:', {
      token: transaction.token ? 'exists' : 'missing',
      redirect_url: transaction.redirect_url ? 'exists' : 'missing'
    });

    // Update order in PocketBase with snap_token combined with midtransOrderId
    try {
      const updateData = {
        payment_status: 'pending_payment',
        snap_token: `${transaction.token}:${midtransOrderId}`,
        redirect_url: transaction.redirect_url
      };
      if (paymentType === 'e_wallet') {
        updateData.paymentMethod = 'E-Wallet';
      } else if (paymentType === 'bank_transfer') {
        updateData.paymentMethod = 'Transfer Bank';
      }
      await pb.collection('orders').update(orderId, updateData);
      console.log('✅ PocketBase order updated with payment method');
    } catch (pbError) {
      console.error('⚠️  PocketBase update error:', pbError.message);
    }

    res.json({
      success: true,
      snap_token: transaction.token,
      redirect_url: transaction.redirect_url,
      order_id: orderId
    });

  } catch (error) {
    console.error('❌ Create transaction error:', error.message);
    console.error('Error details:', error);
    res.status(500).json({
      error: 'Failed to create transaction',
      message: error.message
    });
  }
});

// POST /api/midtrans/webhook
// Handle Midtrans notification webhook
router.post('/midtrans/webhook', async (req, res) => {
  try {
    const notification = req.body;
    
    console.log('📥 Midtrans Webhook received:', {
      order_id: notification.order_id,
      transaction_status: notification.transaction_status,
      fraud_status: notification.fraud_status
    });

    // Verify signature hash
    const serverKey = process.env.MIDTRANS_SERVER_KEY;
    const orderId = notification.order_id;
    const statusCode = notification.status_code;
    const grossAmount = notification.gross_amount;
    const signatureKey = notification.signature_key;

    const hash = crypto
      .createHash('sha512')
      .update(`${orderId}${statusCode}${grossAmount}${serverKey}`)
      .digest('hex');

    if (hash !== signatureKey) {
      console.error('❌ Invalid signature');
      return res.status(403).json({ error: 'Invalid signature' });
    }

    // Get transaction status from Midtrans
    const transactionStatus = notification.transaction_status;
    const fraudStatus = notification.fraud_status;
    const paymentType = notification.payment_type;

    let paymentStatus = 'pending_payment';
    let orderStatus = 'pending';

    // Map Midtrans status to our status
    if (transactionStatus === 'capture') {
      if (fraudStatus === 'accept') {
        paymentStatus = 'paid';
        orderStatus = 'processing';
      }
    } else if (transactionStatus === 'settlement') {
      paymentStatus = 'paid';
      orderStatus = 'processing';
    } else if (transactionStatus === 'pending') {
      paymentStatus = 'pending_payment';
      orderStatus = 'pending';
    } else if (transactionStatus === 'deny' || transactionStatus === 'cancel') {
      paymentStatus = 'fail';
      orderStatus = 'cancelled';
    } else if (transactionStatus === 'expire') {
      paymentStatus = 'fail'; // Changed from 'expired' to 'fail' to match PocketBase options
      orderStatus = 'cancelled';
    } else if (transactionStatus === 'refund') {
      paymentStatus = 'fail'; // Changed from 'refund' to 'fail' to match PocketBase options
      orderStatus = 'cancelled';
    }

    // Update order in PocketBase using realOrderId (by removing the retry suffix)
    const realOrderId = orderId.split('-')[0];
    try {
      const order = await pb.collection('orders').getOne(realOrderId);
      
      const isEWallet = paymentType && (paymentType.includes('wallet') || paymentType.includes('qris') || paymentType.includes('gopay') || paymentType.includes('shopeepay'));
      await pb.collection('orders').update(realOrderId, {
        payment_status: paymentStatus,
        status: orderStatus === 'processing' ? 'Diproses' : 
                orderStatus === 'cancelled' ? 'Dibatalkan' : 'Pending',
        payment_method: paymentType || order.payment_method,
        paymentMethod: paymentType ? (isEWallet ? 'E-Wallet' : 'Transfer Bank') : (order.paymentMethod || 'E-Wallet'),
        paid_at: paymentStatus === 'paid' ? new Date().toISOString() : null
      });

      console.log(`✅ Order ${realOrderId} updated: ${paymentStatus} / ${orderStatus}`);

    } catch (pbError) {
      console.error('PocketBase update error:', pbError);
    }

    res.json({ success: true });

  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).json({
      error: 'Webhook processing failed',
      message: error.message
    });
  }
});

// GET /api/payment-status/:orderId
// Check payment status - cek PocketBase dulu, Midtrans sebagai fallback
router.get('/payment-status/:orderId', async (req, res) => {
  const { orderId } = req.params;
  
  // 1. Cek status dari PocketBase terlebih dahulu
  let orderData = null;
  let pbPaymentStatus = 'pending_payment';
  let midtransOrderId = orderId;
  try {
    const order = await pb.collection('orders').getOne(orderId);
    pbPaymentStatus = order.payment_status || 'pending_payment';
    orderData = {
      payment_status: pbPaymentStatus,
      order_status: order.status,
      paid_at: order.paid_at
    };
    
    // Extract midtransOrderId if stored in snap_token (format: token:midtransOrderId)
    if (order.snap_token && order.snap_token.includes(':')) {
      midtransOrderId = order.snap_token.split(':')[1];
    }
  } catch (pbError) {
    console.log(`PocketBase order not found or error for ${orderId}:`, pbError.message);
  }

  // 2. Coba Midtrans (non-fatal jika gagal)
  let transactionStatus = pbPaymentStatus === 'paid' ? 'settlement' : 'pending';
  let paymentType = null;
  let fraudStatus = null;
  try {
    const statusResponse = await core.transaction.status(midtransOrderId);
    transactionStatus = statusResponse.transaction_status;
    paymentType = statusResponse.payment_type;
    fraudStatus = statusResponse.fraud_status;
  } catch (midtransError) {
    // Tidak fatal - gunakan status dari PocketBase
    console.log(`Midtrans status check skipped for ${midtransOrderId}: ${midtransError.message?.substring(0, 80)}`);
  }

  // Selalu return 200
  res.json({
    success: true,
    order_id: orderId,
    transaction_status: transactionStatus,
    payment_type: paymentType,
    fraud_status: fraudStatus,
    order: orderData
  });
});

// GET /api/success - Midtrans redirect setelah pembayaran berhasil
router.get('/success', async (req, res) => {
  const { order_id } = req.query;
  console.log(`✅ Payment success callback for order: ${order_id}`);
  const realOrderId = order_id ? order_id.split('-')[0] : null;
  if (realOrderId) {
    try {
      await pb.collection('orders').update(realOrderId, {
        payment_status: 'paid',
        status: 'Diproses',
        paid_at: new Date().toISOString()
      });
      console.log(`✅ Order ${realOrderId} updated to paid/Diproses`);
    } catch (e) {
      console.error('Error updating order on success:', e.message);
    }
  }
  res.send(`<!DOCTYPE html><html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pembayaran Berhasil</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#F5F1ED;display:flex;align-items:center;justify-content:center;min-height:100vh}.card{background:white;border-radius:20px;padding:40px 32px;text-align:center;max-width:340px;width:90%;box-shadow:0 8px 32px rgba(0,0,0,.12)}.icon{font-size:64px;margin-bottom:20px;animation:pop .4s ease}@keyframes pop{0%{transform:scale(0)}80%{transform:scale(1.15)}100%{transform:scale(1)}}h1{color:#2C2C2C;font-size:22px;font-weight:700;margin-bottom:10px}p{color:#6B5E52;font-size:14px;line-height:1.6;margin-bottom:8px}.order-id{background:#F5F1ED;border-radius:8px;padding:8px 14px;font-size:13px;color:#C0430E;font-weight:600;margin-bottom:24px;word-break:break-all}.btn{display:inline-block;margin-top:20px;padding:12px 24px;background:#C0430E;color:white;text-decoration:none;border-radius:10px;font-weight:bold;font-size:14px;box-shadow:0 4px 12px rgba(192,67,14,0.2);cursor:pointer;border:none}</style></head><body><div class="card"><div class="icon">✅</div><h1>Pembayaran Berhasil!</h1><p>Pesanan Anda sedang diproses oleh penjual.</p>${realOrderId ? `<div class="order-id">${realOrderId}</div>` : ''}<p style="color:#888;font-size:12px">Halaman ini akan menutup otomatis dalam beberapa detik...</p><button id="close-btn" class="btn" onclick="window.close()">Tutup Halaman</button></div><script>setTimeout(function(){window.close();},2000);</script></body></html>`);
});

// GET /api/failed - Midtrans redirect setelah pembayaran gagal
router.get('/failed', async (req, res) => {
  const { order_id } = req.query;
  console.log(`❌ Payment failed callback for order: ${order_id}`);
  const realOrderId = order_id ? order_id.split('-')[0] : null;
  if (realOrderId) {
    try {
      await pb.collection('orders').update(realOrderId, { payment_status: 'fail' });
    } catch (e) {}
  }
  res.send(`<!DOCTYPE html><html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pembayaran Gagal</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#F5F1ED;display:flex;align-items:center;justify-content:center;min-height:100vh}.card{background:white;border-radius:20px;padding:40px 32px;text-align:center;max-width:340px;width:90%;box-shadow:0 8px 32px rgba(0,0,0,.12)}.icon{font-size:64px;margin-bottom:20px}h1{color:#2C2C2C;font-size:22px;font-weight:700;margin-bottom:10px}p{color:#6B5E52;font-size:14px;line-height:1.6;margin-bottom:24px}.btn{display:inline-block;margin-top:20px;padding:12px 24px;background:#C0430E;color:white;text-decoration:none;border-radius:10px;font-weight:bold;font-size:14px;box-shadow:0 4px 12px rgba(192,67,14,0.2);cursor:pointer;border:none}</style></head><body><div class="card"><div class="icon">❌</div><h1>Pembayaran Gagal</h1><p>Pembayaran tidak berhasil diproses. Silakan kembali ke aplikasi Kartara dan coba lagi.</p><p style="color:#888;font-size:12px">Halaman ini akan menutup otomatis dalam beberapa detik...</p><button id="close-btn" class="btn" onclick="window.close()">Tutup Halaman</button></div><script>setTimeout(function(){window.close();},2500);</script></body></html>`);
});

// GET /api/pending - Midtrans redirect untuk pembayaran pending
router.get('/pending', async (req, res) => {
  const { order_id } = req.query;
  console.log(`⏳ Payment pending callback for order: ${order_id}`);
  res.send(`<!DOCTYPE html><html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Menunggu Pembayaran</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#F5F1ED;display:flex;align-items:center;justify-content:center;min-height:100vh}.card{background:white;border-radius:20px;padding:40px 32px;text-align:center;max-width:340px;width:90%;box-shadow:0 8px 32px rgba(0,0,0,.12)}.icon{font-size:64px;margin-bottom:20px;animation:pulse 1.5s infinite}@keyframes pulse{0%,100%{opacity:1}50%{opacity:.5}}h1{color:#2C2C2C;font-size:22px;font-weight:700;margin-bottom:10px}p{color:#6B5E52;font-size:14px;line-height:1.6;margin-bottom:24px}.btn{display:inline-block;margin-top:20px;padding:12px 24px;background:#C0430E;color:white;text-decoration:none;border-radius:10px;font-weight:bold;font-size:14px;box-shadow:0 4px 12px rgba(192,67,14,0.2);cursor:pointer;border:none}</style></head><body><div class="card"><div class="icon">⏳</div><h1>Menunggu Pembayaran</h1><p>Selesaikan pembayaran Anda sesuai instruksi, lalu kembali ke aplikasi Kartara.</p><p style="color:#888;font-size:12px">Halaman ini akan menutup otomatis dalam beberapa detik...</p><button id="close-btn" class="btn" onclick="window.close()">Tutup Halaman</button></div><script>setTimeout(function(){window.close();},2500);</script></body></html>`);
});

module.exports = router;
