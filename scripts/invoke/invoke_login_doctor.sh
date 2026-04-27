#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"

echo "==> Logging in"
read ACCESS IDT REF EXPIRES <<<$(curl -s -X POST "$API_URL/login" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email":"'"$DOCTOR1_EMAIL"'",
    "password":"'"$DOCTOR1_PASS"'"
  }' | jq -r '.accessToken, .idToken, .refreshToken, .expiresIn')

echo "ID_TOKEN=$IDT"
echo "REFRESH_TOKEN=$REF"
echo "EXPIRES_IN=$EXPIRES"
echo "ACCESS_TOKEN=$ACCESS"
echo "==> Logging in done"


# response=$(
#   curl -s -X POST "$API_URL/login" \
#     -H "Content-Type: application/json" \
#     -H "x-api-key: $API_KEY" \
#     -d '{
#       "email":'$DOCTOR1_EMAIL',
#       "password":'$DOCTOR1_PASS'
#     }'
# )

# echo "Login response JSON:"
# echo "$response" | sed 's/^/  /'