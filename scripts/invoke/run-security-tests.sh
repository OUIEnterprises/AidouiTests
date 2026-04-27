#!/bin/bash

# Run comprehensive security tests
# This wrapper ensures tokens are available for JWT verification tests

set -e

source "$(dirname "$0")/env.sh"

echo "=========================================="
echo "AIDOUI Security Test Suite"
echo "=========================================="
echo ""

# Run login to get tokens
echo "[1] Logging in to get fresh tokens..."
echo ""

LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/login" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "{
    \"email\": \"$PATIENT1_EMAIL\",
    \"password\": \"$PATIENT1_PASS\"
  }")

# Extract tokens
export ID_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.idToken')
export ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.accessToken')
export REFRESH_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.refreshToken')

if [ "$ID_TOKEN" = "null" ] || [ -z "$ID_TOKEN" ]; then
  echo "[0;31m✗ Login failed. Cannot proceed with JWT verification tests.[0m"
  echo "Response: $LOGIN_RESPONSE"
  exit 1
fi

echo "[0;32m✓ Login successful[0m"
echo "  ID Token obtained: ${ID_TOKEN:0:20}..."
echo ""

# Now run JWT verification tests with tokens available
echo "[2] Running JWT Verification Security Tests..."
echo ""

# Re-export for the test script
export ID_TOKEN
export ACCESS_TOKEN
export REFRESH_TOKEN

bash "$(dirname "$0")/test-jwt-verification.sh"
