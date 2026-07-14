require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const bodyParser = require('body-parser');
const paymentRoutes = require('./routes/payment');
const authRoutes = require('./routes/auth');
const chatRoutes = require('./routes/chat');
const shippingRoutes = require('./routes/shipping');
const trackingRoutes = require('./routes/tracking');

const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files
app.use('/static', express.static(path.join(__dirname, 'static')));

// Middleware
const corsOptions = {
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'ngrok-skip-browser-warning',
    'Accept',
    'X-Requested-With',
  ],
  exposedHeaders: ['Content-Range', 'X-Content-Range'],
  credentials: false,
  preflightContinue: false,
  optionsSuccessStatus: 204,
};

// Handle preflight OPTIONS request SEBELUM route lain
app.options('*', cors(corsOptions));
app.use(cors(corsOptions));

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    success: true,
    app: 'Kartara Backend',
    version: '1.0.0',
    status: 'Running 🚀',
    api: '/api',
    health: '/health'
  });
});

// Routes
app.use('/api', paymentRoutes);
app.use('/api', authRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/shipping', shippingRoutes);
app.use('/api/tracking', trackingRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    message: 'Kartara Payment Gateway Backend is running',
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Kartara Payment Gateway Backend running on port ${PORT}`);
  console.log(`📍 Health check: http://localhost:${PORT}/health`);
  console.log(`💳 Payment API: http://localhost:${PORT}/api`);
});
