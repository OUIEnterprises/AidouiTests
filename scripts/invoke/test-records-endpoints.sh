#!/bin/bash

# Test script for records endpoints with proper token usage
# This script demonstrates the correct token types for each endpoint

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Testing Records Endpoints"
echo "=========================================="
echo ""

# Test 1: Patient logs in
echo "1. Patient login..."
PATIENT_EMAIL="patient+1@example.com"
PATIENT_PASSWORD="TempTestPass456!"

PATIENT_LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/login" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$PATIENT_EMAIL\",
    \"password\": \"$PATIENT_PASSWORD\"
  }")

PATIENT_ID_TOKEN=$(echo $PATIENT_LOGIN_RESPONSE | jq -r '.idToken')

if [ "$PATIENT_ID_TOKEN" = "null" ] || [ -z "$PATIENT_ID_TOKEN" ]; then
  echo -e "${RED}❌ Patient login failed${NC}"
  echo "Response: $PATIENT_LOGIN_RESPONSE"
  exit 1
fi
echo -e "${GREEN}✅ Patient logged in${NC}"
echo ""

# Test 2: Doctor logs in
echo "2. Doctor login..."
DOCTOR_EMAIL="doctor+1@example.com"
DOCTOR_PASSWORD="P@ssw0rd!"

DOCTOR_LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/login" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$DOCTOR_EMAIL\",
    \"password\": \"$DOCTOR_PASSWORD\"
  }")

DOCTOR_ID_TOKEN=$(echo $DOCTOR_LOGIN_RESPONSE | jq -r '.idToken')

if [ "$DOCTOR_ID_TOKEN" = "null" ] || [ -z "$DOCTOR_ID_TOKEN" ]; then
  echo -e "${RED}❌ Doctor login failed${NC}"
  echo "Response: $DOCTOR_LOGIN_RESPONSE"
  exit 1
fi
echo -e "${GREEN}✅ Doctor logged in${NC}"
echo ""

# Test 3: Patient shares records
echo "3. Patient shares records (DOCTOR_VISIT purpose)..."
SHARE_RESPONSE=$(curl -s -X POST "$API_URL/records/share" \
  -H "Authorization: Bearer $PATIENT_ID_TOKEN" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "purpose": "DOCTOR_VISIT",
    "ttlSeconds": 3600,
    "recordTypes": ["PRESCRIPTION", "LAB", "VISIT_NOTES"]
  }')

SHARE_CODE=$(echo $SHARE_RESPONSE | jq -r '.code')

if [ "$SHARE_CODE" = "null" ] || [ -z "$SHARE_CODE" ]; then
  echo -e "${RED}❌ Share records failed${NC}"
  echo "Response: $SHARE_RESPONSE"
  exit 1
fi
echo -e "${GREEN}✅ Share code generated: $SHARE_CODE${NC}"
echo ""

# Test 4: Doctor issues pass token
echo "4. Doctor redeems share code to get pass token..."
ISSUE_PASS_RESPONSE=$(curl -s -X POST "$API_URL/records/issue-pass" \
  -H "Authorization: Bearer $DOCTOR_ID_TOKEN" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"code\": \"$SHARE_CODE\"
  }")

PASS_TOKEN=$(echo $ISSUE_PASS_RESPONSE | jq -r '.passToken')

if [ "$PASS_TOKEN" = "null" ] || [ -z "$PASS_TOKEN" ]; then
  echo -e "${RED}❌ Issue pass failed${NC}"
  echo "Response: $ISSUE_PASS_RESPONSE"
  exit 1
fi
echo -e "${GREEN}✅ Pass token issued${NC}"
echo "Capabilities: $(echo $ISSUE_PASS_RESPONSE | jq -r '.capabilities')"
echo ""

# Test 5: GET /records/passes (Doctor uses Cognito JWT)
echo "5. Doctor lists active passes (using Cognito JWT)..."
PASSES_RESPONSE=$(curl -s -X GET "$API_URL/records/passes" \
  -H "Authorization: Bearer $DOCTOR_ID_TOKEN" \
  -H "x-api-key: $API_KEY")

PASSES_COUNT=$(echo $PASSES_RESPONSE | jq -r '.passes | length' 2>/dev/null || echo "error")

if [ "$PASSES_COUNT" = "error" ] || [ "$PASSES_COUNT" = "null" ]; then
  echo -e "${RED}❌ Get passes failed${NC}"
  echo "Response: $PASSES_RESPONSE"
  # Don't exit - this is one of the bugs we're testing
else
  echo -e "${GREEN}✅ Retrieved passes: $PASSES_COUNT pass(es)${NC}"
fi
echo ""

# Test 6: GET /records with pass token
echo "6. Doctor views patient records (using pass token)..."
RECORDS_RESPONSE=$(curl -s -X GET "$API_URL/records" \
  -H "Authorization: Bearer $PASS_TOKEN" \
  -H "x-api-key: $API_KEY")

RECORDS_COUNT=$(echo $RECORDS_RESPONSE | jq -r '.items | length' 2>/dev/null || echo "error")

if [ "$RECORDS_COUNT" = "error" ] || [ "$RECORDS_COUNT" = "null" ]; then
  echo -e "${RED}❌ Get records with pass token failed${NC}"
  echo "Response: $RECORDS_RESPONSE"
else
  echo -e "${GREEN}✅ Retrieved records: $RECORDS_COUNT record(s)${NC}"
  if [ "$RECORDS_COUNT" = "0" ]; then
    echo -e "${YELLOW}⚠️  Warning: No records returned (patient may have no records, or filtering issue)${NC}"
  fi
fi
echo ""

# Test 7: POST /records with pass token (upload new record)
echo "7. Doctor uploads new record (using pass token)..."
echo -e "${YELLOW}⚠️  Skipping - requires multipart/form-data with file upload${NC}"
echo "   To test manually: use curl with -F flag and actual PDF file"
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo "✅ Patient login: SUCCESS"
echo "✅ Doctor login: SUCCESS"
echo "✅ Share records: SUCCESS"
echo "✅ Issue pass: SUCCESS"
echo "Status of buggy endpoints:"
echo "  - GET /records/passes: See result above"
echo "  - GET /records (with pass token): See result above"
echo "  - POST /records: Not tested (requires file upload)"
echo ""
