#!/usr/bin/env bash
set -euo pipefail

# Source environment variables
source "$(dirname "$0")/env.sh"

echo "Testing minimal share request..."
echo ""

# Login as patient
echo "Logging in as $PATIENT1_EMAIL..."
LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/login" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "email": "'"$PATIENT1_EMAIL"'",
    "password": "'"$PATIENT1_PASS"'"
  }')

HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$LOGIN_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ne 200 ]; then
  echo "Login failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

ID_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.idToken')
echo "✓ Login successful"
echo ""

# Test share with minimal fields
echo "Testing share code with minimal fields..."
SHARE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records/share" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{
    "purpose": "DOCTOR_VISIT",
    "ttlSeconds": 3600
  }')

HTTP_CODE=$(echo "$SHARE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$SHARE_RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo "Response:"
echo "$RESPONSE_BODY" | jq '.'
