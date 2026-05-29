# Kartara Payment Gateway Backend

Backend Node.js Express untuk menangani integrasi Midtrans payment gateway dengan PocketBase.

## 🚀 Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Setup Environment Variables

```bash
cp .env.example .env
```

Edit `.env` dengan credentials Anda:

```env
MIDTRANS_SERVER_KEY=your-server-key
MIDTRANS_CLIENT_KEY=your-client-key
MIDTRANS_IS_PRODUCTION=false

POCKETBASE_URL=http://127.0.0.1:8090
POCKETBASE_ADMIN_EMAIL=admin@kartara.com
POCKETBASE_ADMIN_PASSWORD=your-password

PORT=3000
```

### 3. Run Server

**Development (with auto-reload):**
```bash
npm run dev
```

**Production:**
```bash
npm start
```

Server akan berjalan di: `http://localhost:3000`

## 📡 API Endpoints

### Health Check
```
GET /health
```

Response:
```json
{
  "status": "OK",
  "message": "Kartara Payment Gateway Backend is running",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

### Create Transaction
```
POST /api/create-transaction
```

Request Body:
```json
{
  "orderId": "KRT-123456",
  "totalAmount": 50000,
  "customerName": "John Doe",
  "customerEmail": "john@example.com",
  "customerPhone": "081234567890",
  "items": [
    {
      "id": "prod-1",
      "price": 50000,
      "quantity": 1,
      "name": "Krupuk Udang"
    }
  ]
}
```

Response:
```json
{
  "success": true,
  "snap_token": "abc123...",
  "redirect_url": "https://app.sandbox.midtrans.com/snap/v3/...",
  "order_id": "KRT-123456"
}
```

### Midtrans Webhook
```
POST /api/midtrans/webhook
```

Endpoint ini menerima notifikasi dari Midtrans ketika status pembayaran berubah.

### Check Payment Status
```
GET /api/payment-status/:orderId
```

Response:
```json
{
  "success": true,
  "order_id": "KRT-123456",
  "transaction_status": "settlement",
  "payment_type": "gopay",
  "fraud_status": "accept",
  "order": {
    "payment_status": "paid",
    "order_status": "Diproses",
    "paid_at": "2024-01-01T00:00:00.000Z"
  }
}
```

## 🔒 Security

- ✅ Midtrans Server Key disimpan di environment variables
- ✅ Webhook signature verification
- ✅ CORS enabled untuk Flutter app
- ✅ Request validation

## 📁 Project Structure

```
backend/
├── config/
│   ├── midtrans.js      # Midtrans client configuration
│   └── pocketbase.js    # PocketBase connection
├── routes/
│   └── payment.js       # Payment API routes
├── .env.example         # Environment variables template
├── .gitignore          # Git ignore file
├── package.json        # Dependencies
├── server.js           # Express server
└── README.md           # This file
```

## 🧪 Testing

### Test Health Check
```bash
curl http://localhost:3000/health
```

### Test Create Transaction
```bash
curl -X POST http://localhost:3000/api/create-transaction \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "KRT-TEST-001",
    "totalAmount": 50000,
    "customerName": "Test User",
    "customerEmail": "test@kartara.com",
    "customerPhone": "081234567890"
  }'
```

### Test Payment Status
```bash
curl http://localhost:3000/api/payment-status/KRT-TEST-001
```

## 🐛 Troubleshooting

### Port already in use
```bash
# Kill process on port 3000
# Windows:
netstat -ano | findstr :3000
taskkill /PID <PID> /F

# Linux/Mac:
lsof -ti:3000 | xargs kill -9
```

### PocketBase connection failed
- Pastikan PocketBase berjalan di `http://127.0.0.1:8090`
- Cek credentials admin di `.env`

### Midtrans API error
- Pastikan menggunakan Sandbox credentials untuk testing
- Cek Server Key dan Client Key di Midtrans Dashboard

## 📦 Dependencies

- **express**: Web framework
- **dotenv**: Environment variables
- **axios**: HTTP client
- **cors**: CORS middleware
- **midtrans-client**: Midtrans SDK
- **pocketbase**: PocketBase SDK
- **body-parser**: Request body parser
- **crypto**: Signature verification

## 🔄 Webhook Flow

1. User melakukan pembayaran di Midtrans
2. Midtrans mengirim notifikasi ke `/api/midtrans/webhook`
3. Backend verify signature
4. Backend update status di PocketBase
5. Flutter app polling atau real-time update status

## 📝 Notes

- Gunakan **Sandbox** mode untuk testing
- Untuk production, set `MIDTRANS_IS_PRODUCTION=true`
- Setup webhook URL di Midtrans Dashboard untuk production
- Gunakan HTTPS untuk production backend

## 📞 Support

Untuk bantuan lebih lanjut, lihat dokumentasi:
- [Midtrans Documentation](https://docs.midtrans.com/)
- [PocketBase Documentation](https://pocketbase.io/docs/)
- [Express Documentation](https://expressjs.com/)
