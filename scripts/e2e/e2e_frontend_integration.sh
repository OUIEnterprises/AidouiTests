#!/usr/bin/env bash
set -euo pipefail

# Frontend Integration Test
# Tests that frontend workflows integrate correctly with backend

source "$(dirname "$0")/../invoke/env.sh"

echo "======================================"
echo "E2E Test: Frontend Integration"
echo "======================================"
echo ""

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

# ====================================
# Test 1: Pharmacy Capability Check
# ====================================
print_step "Test 1: Pharmacy capabilities (should NOT allow upload)..."

# 1. Patient creates share code for pharmacy
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
  print_success "Patient logged in"
else
  print_error "Patient login failed (HTTP $HTTP_CODE)"
  exit 1
fi

# Patient generates share code for pharmacy
SHARE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records/share" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PATIENT_ID_TOKEN" \
  -d '{
    "purpose": "PHARMACY_FILL",
    "ttlSeconds": 3600,
    "label": "Pharmacy Fill - Frontend Test",
    "recordTypes": ["PRESCRIPTION"]
  }')

HTTP_CODE=$(echo "$SHARE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$SHARE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  PHARMACY_CODE=$(echo "$RESPONSE_BODY" | jq -r '.code')
  print_success "Share code for pharmacy: $PHARMACY_CODE"
else
  print_error "Share code generation failed (HTTP $HTTP_CODE)"
  exit 1
fi

# 2. Pharmacy logs in and redeems code
LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/login" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "email": "'"$PHARMACY1_EMAIL"'",
    "password": "'"$PHARMACY1_PASS"'"
  }')

HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$LOGIN_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  PHARMACY_ID_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.idToken')
  print_success "Pharmacy logged in"
else
  print_error "Pharmacy login failed (HTTP $HTTP_CODE)"
  exit 1
fi

# Pharmacy redeems code
ISSUE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records/issue-pass" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PHARMACY_ID_TOKEN" \
  -d '{
    "code": "'"$PHARMACY_CODE"'"
  }')

HTTP_CODE=$(echo "$ISSUE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$ISSUE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  PHARMACY_PASS_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.passToken')
  PHARMACY_CAPABILITIES=$(echo "$RESPONSE_BODY" | jq -r '.capabilities')
  CAN_VIEW=$(echo "$PHARMACY_CAPABILITIES" | jq -r '.canView')
  CAN_UPLOAD=$(echo "$PHARMACY_CAPABILITIES" | jq -r '.canUpload')

  print_success "Pharmacy redeemed code"
  print_info "Capabilities: canView=$CAN_VIEW, canUpload=$CAN_UPLOAD"

  if [ "$CAN_VIEW" = "true" ] && [ "$CAN_UPLOAD" = "false" ]; then
    print_success "✓ Pharmacy has correct capabilities (view only)"
  else
    print_error "✗ Pharmacy capabilities incorrect! Expected canView=true, canUpload=false"
    echo "Got: canView=$CAN_VIEW, canUpload=$CAN_UPLOAD"
    exit 1
  fi
else
  print_error "Code redemption failed (HTTP $HTTP_CODE)"
  exit 1
fi

sleep 1

# ====================================
# Test 2: Doctor Capability Check
# ====================================
print_step "Test 2: Doctor capabilities (should allow upload)..."

# Patient generates share code for doctor
SHARE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records/share" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PATIENT_ID_TOKEN" \
  -d '{
    "purpose": "DOCTOR_VISIT",
    "ttlSeconds": 3600,
    "label": "Doctor Visit - Frontend Test",
    "recordTypes": ["VISIT_NOTES", "PRESCRIPTION", "LAB"]
  }')

HTTP_CODE=$(echo "$SHARE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$SHARE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  DOCTOR_CODE=$(echo "$RESPONSE_BODY" | jq -r '.code')
  print_success "Share code for doctor: $DOCTOR_CODE"
else
  print_error "Share code generation failed (HTTP $HTTP_CODE)"
  exit 1
fi

# Doctor logs in and redeems code
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
  print_success "Doctor logged in"
else
  print_error "Doctor login failed (HTTP $HTTP_CODE)"
  exit 1
fi

ISSUE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records/issue-pass" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $DOCTOR_ID_TOKEN" \
  -d '{
    "code": "'"$DOCTOR_CODE"'"
  }')

HTTP_CODE=$(echo "$ISSUE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$ISSUE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  DOCTOR_PASS_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.passToken')
  DOCTOR_CAPABILITIES=$(echo "$RESPONSE_BODY" | jq -r '.capabilities')
  CAN_VIEW=$(echo "$DOCTOR_CAPABILITIES" | jq -r '.canView')
  CAN_UPLOAD=$(echo "$DOCTOR_CAPABILITIES" | jq -r '.canUpload')

  print_success "Doctor redeemed code"
  print_info "Capabilities: canView=$CAN_VIEW, canUpload=$CAN_UPLOAD"

  if [ "$CAN_VIEW" = "true" ] && [ "$CAN_UPLOAD" = "true" ]; then
    print_success "✓ Doctor has correct capabilities (view and upload)"
  else
    print_error "✗ Doctor capabilities incorrect! Expected canView=true, canUpload=true"
    echo "Got: canView=$CAN_VIEW, canUpload=$CAN_UPLOAD"
    exit 1
  fi
else
  print_error "Code redemption failed (HTTP $HTTP_CODE)"
  exit 1
fi

sleep 1

# ====================================
# Test 3: Pharmacy Upload Prevention
# ====================================
print_step "Test 3: Pharmacy upload attempt (should fail with 403)..."

LAB_FILE="/Users/waelelhajj/Documents/AIDOUI/AidouiCDK/test/fixtures/TestLabResult.pdf"
if [ ! -f "$LAB_FILE" ]; then
  print_error "Test file not found: $LAB_FILE"
  exit 1
fi

UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PHARMACY_PASS_TOKEN" \
  -F "metadata={\"type\":\"PRESCRIPTION\",\"notes\":\"Pharmacy upload attempt - should fail\"}" \
  -F "file=@$LAB_FILE")

HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 403 ]; then
  print_success "✓ Pharmacy upload correctly blocked (HTTP 403)"
else
  print_error "✗ Expected HTTP 403, got HTTP $HTTP_CODE"
  echo "$UPLOAD_RESPONSE" | sed '$d' | jq '.'
  exit 1
fi

sleep 1

# ====================================
# Test 4: Frontend Upload Format
# ====================================
print_step "Test 4: Doctor uploads with frontend format (multipart with metadata)..."

UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $DOCTOR_PASS_TOKEN" \
  -F "metadata={\"type\":\"VISIT_NOTES\",\"notes\":\"Frontend integration test - visit notes\",\"diagnosisCode\":\"Z00.00\"}" \
  -F "file=@$LAB_FILE")

HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$UPLOAD_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
  RECORD_ID=$(echo "$RESPONSE_BODY" | jq -r '.id // "N/A"')
  print_success "✓ Doctor uploaded record with frontend format"
  print_info "Record ID: $RECORD_ID"
else
  print_error "✗ Upload failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

sleep 1

# ====================================
# Test 5: Patient Record Retrieval
# ====================================
print_step "Test 5: Patient retrieves uploaded records..."

RECORDS_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$API_URL/records" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PATIENT_ID_TOKEN")

HTTP_CODE=$(echo "$RECORDS_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RECORDS_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  RECORD_COUNT=$(echo "$RESPONSE_BODY" | jq '.items | length')
  print_success "✓ Patient retrieved $RECORD_COUNT record(s)"

  # Check if the newly uploaded record exists
  NEW_RECORD=$(echo "$RESPONSE_BODY" | jq ".items[] | select(.id == \"$RECORD_ID\")")
  if [ -n "$NEW_RECORD" ]; then
    print_success "✓ Newly uploaded record found in patient's records"
    echo "$NEW_RECORD" | jq '{id, type, notes}'
  else
    print_error "✗ Newly uploaded record NOT found in patient's records"
    exit 1
  fi
else
  print_error "✗ Record retrieval failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

echo ""
echo "======================================"
echo -e "${GREEN}✓ Frontend Integration Test Passed!${NC}"
echo "======================================"
echo ""
echo "Summary:"
echo "  ✓ Pharmacy capabilities: canView=true, canUpload=false"
echo "  ✓ Doctor capabilities: canView=true, canUpload=true"
echo "  ✓ Pharmacy upload blocked (HTTP 403)"
echo "  ✓ Doctor upload with frontend format succeeded"
echo "  ✓ Patient can retrieve uploaded records"
echo ""
