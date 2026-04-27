#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"

echo "======================================"
echo "Creating Test Accounts"
echo "======================================"
echo ""

# CREATE PATIENT
echo "Creating Patient: $PATIENT1_EMAIL"
curl -i -X POST "$API_URL/signup" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "email": "'"$PATIENT1_EMAIL"'",
    "password": "'"$PATIENT1_PASS"'",
    "givenName": "Sick",
    "familyName": "Patient1",
    "phoneNumber": "+15551234567",
    "role": "'"$PATIENT1_ROLE"'"
  }'

echo ""
echo "======================================"
echo ""

# CREATE DOCTOR
echo "Creating Doctor: $DOCTOR1_EMAIL"
curl -i -X POST "$API_URL/signup" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "email": "'"$DOCTOR1_EMAIL"'",
    "password": "'"$DOCTOR1_PASS"'",
    "givenName": "First",
    "familyName": "Doctor1",
    "phoneNumber": "+15551234579",
    "role": "'"$DOCTOR1_ROLE"'",
    "licenseNumber": "MD123456",
    "specialty": "General Practice"
  }'

echo ""
echo "======================================"
echo "Done creating accounts"
echo "======================================"


