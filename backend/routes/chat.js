const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');

// Chat endpoint - main conversation
router.post('/', chatController.handleChat);

// Quick reply endpoint - predefined actions
router.post('/quick-reply', chatController.handleQuickReply);

// Product recommendation endpoint
router.post('/recommendation', chatController.getRecommendation);

// Order status endpoint
router.post('/order-status', chatController.getOrderStatus);

module.exports = router;
