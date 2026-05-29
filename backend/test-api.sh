#!/bin/bash

# Kartara Payment Gateway API Testing Script
# Usage: ./test-api.sh

BASE_URL="http://localhost:3000"
ORDER_ID="KRT-TEST-$(date +%s)"

echo "🧪 Testing Kartara Payment Gateway API"
echo "========================================"
echo ""

# Test 1: Health Check
echo "1️⃣  Testing Health Check..."
echo "GET $BASE_URL/health"
echo ""
curl -s $BASE_URL/health | json_pp
echo ""
echo "✅ Health check completed"
echo ""
echo "========================================"
echo ""

# Test 2: Create Transaction
echo "2️⃣  Testing Create Transaction..."
echo "POST $BASE_URL/api/create-transaction"
echo "Order ID: $ORDER_ID"
echo ""
RESPONSE=$(curl -s -X POST $BASE_URL/api/create-transaction \
  -H "Content-Type: application/json" \
  -d "{
    \"orderId\": \"$ORDER_ID\",
    \"totalAmount\": 50000,
    \"customerName\": \"Test User\",
    \"customerEmail\": \"test@kartara.com\",
    \"customerPhone\": \"081234567890\",
    \"items\": [
      {
        \"id\": \"prod-1\",
        \"price\": 50000,
        \"quantity\": 1,
        \"name\": \"Krupuk Udang Test\"
      }
    ]
  }")

echo $RESPONSE | json_pp
echo ""

# Extract snap_token and redirect_url
SNAP_TOKEN=$(echo $RESPONSE | grep -o '"snap_token":"[^"]*' | cut -d'"' -f4)
REDIRECT_URL=$(echo $RESPONSE | grep -o '"redirect_url":"[^"]*' | cut -d'"' -f4)

if [ ! -z "$SNAP_TOKEN" ]; then
  echo "✅ Transaction created successfully"
  echo "📝 Snap Token: $SNAP_TOKEN"
  echo "🔗 Redirect URL: $REDIRECT_URL"
else
  echo "❌ Failed to create transaction"
fi

echo ""
echo "========================================"
echo ""

# Test 3: Check Payment Status
echo "3️⃣  Testing Payment Status..."
echo "GET $BASE_URL/api/payment-status/$ORDER_ID"
echo ""
sleep 2
curl -s $BASE_URL/api/payment-status/$ORDER_ID | json_pp
echo ""
echo "✅ Payment status check completed"
echo ""
echo "========================================"
echo ""

echo "🎉 All tests completed!"
echo ""
echo "📌 Next steps:"
echo "   1. Open the redirect URL in browser to test payment"
echo "   2. Use Midtrans Simulator for testing"
echo "   3. Check webhook logs in backend console"
echo ""
