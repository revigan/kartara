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

    // Create transaction parameter
    const parameter = {
      transaction_details: {
        order_id: orderId,
        gross_amount: grossAmount
      },
      customer_details: {
        first_name: customerName,
        email: customerEmail,
        phone: customerPhone
      },
      item_details: itemDetails,
      callbacks: {
        finish: `${process.env.FRONTEND_URL}/success?order_id=${orderId}`,
        error: `${process.env.FRONTEND_URL}/failed?order_id=${orderId}`,
        pending: `${process.env.FRONTEND_URL}/pending?order_id=${orderId}`
      }
    };

    console.log('📤 Creating Midtrans transaction with parameter:', {
      order_id: parameter.transaction_details.order_id,
      gross_amount: parameter.transaction_details.gross_amount
    });

    // Create Snap transaction
    const transaction = await snap.createTransaction(parameter);

    console.log('✅ Midtrans transaction created:', {
      token: transaction.token ? 'exists' : 'missing',
      redirect_url: transaction.redirect_url ? 'exists' : 'missing'
    });

    // Update order in PocketBase with snap_token
    try {
      await pb.collection('orders').update(orderId, {
        payment_status: 'pending_payment',
        snap_token: transaction.token,
        redirect_url: transaction.redirect_url
      });
      console.log('✅ PocketBase order updated');
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

    // Update order in PocketBase
    try {
      const order = await pb.collection('orders').getOne(orderId);
      
      await pb.collection('orders').update(orderId, {
        payment_status: paymentStatus,
        status: orderStatus === 'processing' ? 'Diproses' : 
                orderStatus === 'cancelled' ? 'Dibatalkan' : 'Pending',
        payment_method: paymentType || order.payment_method,
        paid_at: paymentStatus === 'paid' ? new Date().toISOString() : null
      });

      console.log(`✅ Order ${orderId} updated: ${paymentStatus} / ${orderStatus}`);

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
  try {
    const order = await pb.collection('orders').getOne(orderId);
    pbPaymentStatus = order.payment_status || 'pending_payment';
    orderData = {
      payment_status: pbPaymentStatus,
      order_status: order.status,
      paid_at: order.paid_at
    };
  } catch (pbError) {
    console.log(`PocketBase order not found or error for ${orderId}:`, pbError.message);
  }

  // 2. Coba Midtrans (non-fatal jika gagal)
  let transactionStatus = pbPaymentStatus === 'paid' ? 'settlement' : 'pending';
  let paymentType = null;
  let fraudStatus = null;
  try {
    const statusResponse = await core.transaction.status(orderId);
    transactionStatus = statusResponse.transaction_status;
    paymentType = statusResponse.payment_type;
    fraudStatus = statusResponse.fraud_status;
  } catch (midtransError) {
    // Tidak fatal - gunakan status dari PocketBase
    console.log(`Midtrans status check skipped for ${orderId}: ${midtransError.message?.substring(0, 80)}`);
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
  if (order_id) {
    try {
      await pb.collection('orders').update(order_id, {
        payment_status: 'paid',
        status: 'Diproses',
        paid_at: new Date().toISOString()
      });
      console.log(`✅ Order ${order_id} updated to paid/Diproses`);
    } catch (e) {
      console.error('Error updating order on success:', e.message);
    }
  }
  res.send(`<!DOCTYPE html><html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pembayaran Berhasil</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,sans-serif;background:#F5F1ED;display:flex;align-items:center;justify-content:center;min-height:100vh}.card{background:white;border-radius:16px;padding:40px;text-align:center;max-width:340px;width:90%;box-shadow:0 4px 20px rgba(0,0,0,.1)}.icon{font-size:60px;margin-bottom:16px}h1{color:#2C2C2C;font-size:20px;margin-bottom:8px}p{color:#6B5E52;font-size:13px;margin-bottom:24px;line-height:1.5}.btn{background:#C0430E;color:white;border:none;padding:14px;border-radius:12px;font-size:15px;font-weight:bold;cursor:pointer;width:100%}</style><script>setTimeout(()=>{window.close()},3000)</script></head><body><div class="card"><div class="icon">✅</div><h1>Pembayaran Berhasil!</h1><p>Pesanan Anda sedang diproses. Tab ini akan otomatis tertutup.</p><button class="btn" onclick="window.close()">Kembali ke Kartara</button></div></body></html>`);
});

// GET /api/failed - Midtrans redirect setelah pembayaran gagal
router.get('/failed', async (req, res) => {
  const { order_id } = req.query;
  console.log(`❌ Payment failed callback for order: ${order_id}`);
  if (order_id) {
    try {
      await pb.collection('orders').update(order_id, { payment_status: 'fail' });
    } catch (e) {}
  }
  res.send(`<!DOCTYPE html><html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pembayaran Gagal</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,sans-serif;background:#F5F1ED;display:flex;align-items:center;justify-content:center;min-height:100vh}.card{background:white;border-radius:16px;padding:40px;text-align:center;max-width:340px;width:90%;box-shadow:0 4px 20px rgba(0,0,0,.1)}.icon{font-size:60px;margin-bottom:16px}h1{color:#2C2C2C;font-size:20px;margin-bottom:8px}p{color:#6B5E52;font-size:13px;margin-bottom:24px;line-height:1.5}.btn{background:#C0430E;color:white;border:none;padding:14px;border-radius:12px;font-size:15px;font-weight:bold;cursor:pointer;width:100%}</style><script>setTimeout(()=>{window.close()},3000)</script></head><body><div class="card"><div class="icon">❌</div><h1>Pembayaran Gagal</h1><p>Pembayaran tidak berhasil. Silakan coba lagi.</p><button class="btn" onclick="window.close()">Kembali ke Kartara</button></div></body></html>`);
});

// GET /api/pending - Midtrans redirect untuk pembayaran pending
router.get('/pending', async (req, res) => {
  const { order_id } = req.query;
  console.log(`⏳ Payment pending callback for order: ${order_id}`);
  res.send(`<!DOCTYPE html><html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Menunggu Pembayaran</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,sans-serif;background:#F5F1ED;display:flex;align-items:center;justify-content:center;min-height:100vh}.card{background:white;border-radius:16px;padding:40px;text-align:center;max-width:340px;width:90%;box-shadow:0 4px 20px rgba(0,0,0,.1)}.icon{font-size:60px;margin-bottom:16px}h1{color:#2C2C2C;font-size:20px;margin-bottom:8px}p{color:#6B5E52;font-size:13px;margin-bottom:24px;line-height:1.5}.btn{background:#C0430E;color:white;border:none;padding:14px;border-radius:12px;font-size:15px;font-weight:bold;cursor:pointer;width:100%}</style><script>setTimeout(()=>{window.close()},5000)</script></head><body><div class="card"><div class="icon">⏳</div><h1>Menunggu Pembayaran</h1><p>Selesaikan pembayaran Anda, lalu kembali ke aplikasi Kartara.</p><button class="btn" onclick="window.close()">Kembali ke Kartara</button></div></body></html>`);
});

module.exports = router;
