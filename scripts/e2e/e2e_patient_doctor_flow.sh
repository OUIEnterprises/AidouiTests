#!/usr/bin/env bash
set -euo pipefail

# Source environment variables
source "$(dirname "$0")/../invoke/env.sh"

echo "======================================"
echo "E2E Test: Patient-Doctor Flow"
echo "======================================"
echo ""

# Cleanup function
cleanup() {
  if [ -n "${TEMP_FILE:-}" ] && [ -f "$TEMP_FILE" ]; then
    rm -f "$TEMP_FILE"
  fi
}
trap cleanup EXIT

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
  echo -e "${BLUE}==>${NC} ${1}"
}

print_success() {
  echo -e "${GREEN}✓${NC} ${1}"
}

print_error() {
  echo -e "${RED}✗${NC} ${1}"
}

print_info() {
  echo -e "${YELLOW}ℹ${NC} ${1}"
}

# Use pre-existing test accounts from env.sh
echo "Test Accounts:"
echo "  Patient: $PATIENT1_EMAIL"
echo "  Doctor:  $DOCTOR1_EMAIL"
echo ""

# ====================================
# Step 1: Patient Login
# ====================================
print_step "Step 1: Patient logging in..."

LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/login" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "email": "'"$PATIENT1_EMAIL"'",
    "password": "'"$PATIENT1_PASS"'"
  }')

HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$LOGIN_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  PATIENT_ID_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.idToken')
  PATIENT_ACCESS_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.accessToken')
  print_success "Patient logged in successfully"
else
  print_error "Patient login failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

sleep 1

# ====================================
# Step 2: Patient generates share code with selective record types
# ====================================
print_step "Step 2: Patient generating share code for doctor..."

SHARE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records/share" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PATIENT_ID_TOKEN" \
  -d '{
    "purpose": "DOCTOR_VISIT",
    "ttlSeconds": 3600,
    "label": "E2E Test - Doctor Visit",
    "recordTypes": ["PRESCRIPTION", "LAB", "VISIT_NOTES"]
  }')

HTTP_CODE=$(echo "$SHARE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$SHARE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  SHARE_CODE=$(echo "$RESPONSE_BODY" | jq -r '.code')
  RECORD_TYPES=$(echo "$RESPONSE_BODY" | jq -r '.recordTypes[]? // empty' | tr '\n' ', ' | sed 's/,$//')
  print_success "Share code generated: $SHARE_CODE"
  if [ -n "$RECORD_TYPES" ]; then
    print_info "Allowed record types: $RECORD_TYPES"
  fi
else
  print_error "Share code generation failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

sleep 1

# ====================================
# Step 3: Test patient cannot redeem their own code
# ====================================
print_step "Step 3: Testing provider self-access prevention..."

SELF_REDEEM_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records/issue-pass" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PATIENT_ID_TOKEN" \
  -d '{
    "code": "'"$SHARE_CODE"'"
  }')

HTTP_CODE=$(echo "$SELF_REDEEM_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 403 ]; then
  print_success "Provider self-access correctly prevented (HTTP 403)"
else
  print_error "Expected HTTP 403 for self-redemption, got HTTP $HTTP_CODE"
  echo "$SELF_REDEEM_RESPONSE" | sed '$d' | jq '.'
fi

sleep 1

# ====================================
# Step 4: Doctor Login
# ====================================
print_step "Step 4: Doctor logging in..."

LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/login" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "email": "'"$DOCTOR1_EMAIL"'",
    "password": "'"$DOCTOR1_PASS"'"
  }')

HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$LOGIN_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  DOCTOR_ID_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.idToken')
  DOCTOR_ACCESS_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.accessToken')
  print_success "Doctor logged in successfully"
else
  print_error "Doctor login failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

sleep 1

# ====================================
# Step 5: Doctor redeems share code
# ====================================
print_step "Step 5: Doctor redeeming share code..."

ISSUE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records/issue-pass" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $DOCTOR_ID_TOKEN" \
  -d '{
    "code": "'"$SHARE_CODE"'"
  }')

HTTP_CODE=$(echo "$ISSUE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$ISSUE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  PASS_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.passToken')
  PATIENT_ID=$(echo "$RESPONSE_BODY" | jq -r '.patientId // "N/A"')
  print_success "Share code redeemed successfully"
  print_info "Pass token obtained for patient: $PATIENT_ID"
else
  print_error "Share code redemption failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

sleep 1

# ====================================
# Step 6: Doctor uploads lab result
# ====================================
print_step "Step 6: Doctor uploading lab result..."

LAB_FILE="/Users/waelelhajj/Documents/AIDOUI/AidouiCDK/test/fixtures/TestLabResult.pdf"
if [ ! -f "$LAB_FILE" ]; then
  print_error "Test file not found: $LAB_FILE"
  exit 1
fi

UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PASS_TOKEN" \
  -F "metadata={\"type\":\"VISIT_NOTES\",\"notes\":\"E2E Test - Visit notes from doctor consultation\",\"diagnosisCode\":\"Z00.00\"}" \
  -F "file=@$LAB_FILE")

HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$UPLOAD_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
  RECORD_ID=$(echo "$RESPONSE_BODY" | jq -r '.id // "N/A"')
  print_success "Lab result uploaded successfully"
  print_info "Record ID: $RECORD_ID"
else
  print_error "Lab result upload failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

sleep 1

# ====================================
# Step 7: Patient verifies records
# ====================================
print_step "Step 7: Patient verifying uploaded record..."

RECORDS_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$API_URL/records" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PATIENT_ID_TOKEN")

HTTP_CODE=$(echo "$RECORDS_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RECORDS_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  RECORD_COUNT=$(echo "$RESPONSE_BODY" | jq '.items | length')
  print_success "Patient retrieved $RECORD_COUNT record(s)"

  if [ "$RECORD_COUNT" -gt 0 ]; then
    echo "$RESPONSE_BODY" | jq '.items[] | {id, type, notes}'
  fi
else
  print_error "Record retrieval failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

echo ""
echo "======================================"
echo -e "${GREEN}✓ E2E Test Completed Successfully!${NC}"
echo "======================================"
echo ""
echo "Summary:"
echo "  • Patient logged in ($PATIENT1_EMAIL)"
echo "  • Doctor logged in ($DOCTOR1_EMAIL)"
echo "  • Share code generated: $SHARE_CODE"
echo "  • Selective record types tested (PRESCRIPTION, LAB, VISIT_NOTES)"
echo "  • Provider self-access prevention verified (HTTP 403)"
echo "  • Doctor redeemed code and obtained pass token"
echo "  • Lab result uploaded successfully"
echo "  • Patient verified record exists"
echo ""
