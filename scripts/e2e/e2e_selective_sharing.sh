#!/usr/bin/env bash
set -euo pipefail

# Source environment variables
source "$(dirname "$0")/../invoke/env.sh"

echo "======================================"
echo "E2E Test: Selective Record Sharing"
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
echo "  Patient: $PATIENT2_EMAIL"
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
    "email": "'"$PATIENT2_EMAIL"'",
    "password": "'"$PATIENT2_PASS"'"
  }')

HTTP_CODE=$(echo "$LOGIN_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 200 ]; then
  PATIENT_ID_TOKEN=$(echo "$LOGIN_RESPONSE" | sed '$d' | jq -r '.idToken')
  print_success "Patient logged in successfully"
else
  print_error "Patient login failed (HTTP $HTTP_CODE)"
  echo "$LOGIN_RESPONSE" | sed '$d' | jq '.'
  exit 1
fi

sleep 1

# ====================================
# Step 2: Patient creates multiple record types
# ====================================
print_step "Step 2: Patient uploading multiple record types..."

LAB_FILE="../fixtures/TestLabResult.pdf"
if [ ! -f "$LAB_FILE" ]; then
  print_error "Test file not found: $LAB_FILE"
  exit 1
fi

# Upload PRESCRIPTION record
print_info "Uploading PRESCRIPTION record..."
UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PATIENT_ID_TOKEN" \
  -F "type=PRESCRIPTION" \
  -F "notes=Test Prescription - Amoxicillin 500mg" \
  -F "diagnosisCode=J01.90" \
  -F "file=@$LAB_FILE")

HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -n1)
if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
  RX_RECORD_ID=$(echo "$UPLOAD_RESPONSE" | sed '$d' | jq -r '.id')
  print_success "PRESCRIPTION uploaded (ID: $RX_RECORD_ID)"
else
  print_error "PRESCRIPTION upload failed (HTTP $HTTP_CODE)"
  exit 1
fi

sleep 1

# Upload LAB record
print_info "Uploading LAB record..."
UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PATIENT_ID_TOKEN" \
  -F "type=LAB" \
  -F "notes=Test Lab Result - Blood Work" \
  -F "diagnosisCode=Z00.00" \
  -F "file=@$LAB_FILE")

HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -n1)
if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
  LAB_RECORD_ID=$(echo "$UPLOAD_RESPONSE" | sed '$d' | jq -r '.id')
  print_success "LAB uploaded (ID: $LAB_RECORD_ID)"
else
  print_error "LAB upload failed (HTTP $HTTP_CODE)"
  exit 1
fi

sleep 1

# Upload VISIT_NOTES record
print_info "Uploading VISIT_NOTES record..."
UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PATIENT_ID_TOKEN" \
  -F "type=VISIT_NOTES" \
  -F "notes=Test Visit Notes - Annual Checkup" \
  -F "diagnosisCode=Z00.00" \
  -F "file=@$LAB_FILE")

HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -n1)
if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
  VISIT_RECORD_ID=$(echo "$UPLOAD_RESPONSE" | sed '$d' | jq -r '.id')
  print_success "VISIT_NOTES uploaded (ID: $VISIT_RECORD_ID)"
else
  print_error "VISIT_NOTES upload failed (HTTP $HTTP_CODE)"
  exit 1
fi

sleep 1

# ====================================
# Step 3: Patient generates share code with ONLY LAB records
# ====================================
print_step "Step 3: Patient generating share code with ONLY LAB access..."

SHARE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records/share" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PATIENT_ID_TOKEN" \
  -d '{
    "purpose": "DOCTOR_VISIT",
    "ttlSeconds": 3600,
    "label": "E2E Test - Selective Sharing (LAB only)",
    "recordTypes": ["LAB"]
  }')

HTTP_CODE=$(echo "$SHARE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$SHARE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  SHARE_CODE=$(echo "$RESPONSE_BODY" | jq -r '.code')
  RETURNED_TYPES=$(echo "$RESPONSE_BODY" | jq -r '.recordTypes[]?' | tr '\n' ', ' | sed 's/,$//')
  print_success "Share code generated: $SHARE_CODE"
  print_info "Allowed record types: $RETURNED_TYPES"

  # Verify only LAB is allowed
  if [ "$RETURNED_TYPES" = "LAB" ]; then
    print_success "Selective sharing correctly configured (LAB only)"
  else
    print_error "Expected only LAB, got: $RETURNED_TYPES"
    exit 1
  fi
else
  print_error "Share code generation failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
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

if [ "$HTTP_CODE" -eq 200 ]; then
  DOCTOR_ID_TOKEN=$(echo "$LOGIN_RESPONSE" | sed '$d' | jq -r '.idToken')
  print_success "Doctor logged in successfully"
else
  print_error "Doctor login failed (HTTP $HTTP_CODE)"
  echo "$LOGIN_RESPONSE" | sed '$d' | jq '.'
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
  print_success "Share code redeemed successfully"
else
  print_error "Share code redemption failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

sleep 1

# ====================================
# Step 6: Doctor retrieves patient records (should only see LAB)
# ====================================
print_step "Step 6: Doctor retrieving patient records with pass token..."

RECORDS_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$API_URL/records" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $DOCTOR_ID_TOKEN" \
  -H "x-pass-token: $PASS_TOKEN")

HTTP_CODE=$(echo "$RECORDS_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RECORDS_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  RECORD_COUNT=$(echo "$RESPONSE_BODY" | jq '.items | length')
  print_success "Retrieved $RECORD_COUNT record(s)"

  # Verify doctor can only see LAB records
  RECORD_TYPES=$(echo "$RESPONSE_BODY" | jq -r '.items[].type' | sort -u | tr '\n' ', ' | sed 's/,$//')

  if [ "$RECORD_COUNT" -eq 1 ] && [ "$RECORD_TYPES" = "LAB" ]; then
    print_success "Selective sharing working correctly - Doctor can only see LAB records"
  else
    print_error "Selective sharing failed - Expected 1 LAB record, got $RECORD_COUNT records of types: $RECORD_TYPES"
    echo "$RESPONSE_BODY" | jq '.items[] | {id, type, notes}'
    exit 1
  fi
else
  print_error "Record retrieval failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

sleep 1

# ====================================
# Step 7: Generate a second share code with ALL record types
# ====================================
print_step "Step 7: Patient generating share code with ALL record types..."

SHARE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records/share" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $PATIENT_ID_TOKEN" \
  -d '{
    "purpose": "DOCTOR_VISIT",
    "ttlSeconds": 3600,
    "label": "E2E Test - All Records",
    "recordTypes": ["PRESCRIPTION", "LAB", "VISIT_NOTES"]
  }')

HTTP_CODE=$(echo "$SHARE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$SHARE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  ALL_SHARE_CODE=$(echo "$RESPONSE_BODY" | jq -r '.code')
  print_success "All-access share code generated: $ALL_SHARE_CODE"
else
  print_error "Share code generation failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

sleep 1

# ====================================
# Step 8: Doctor redeems all-access code
# ====================================
print_step "Step 8: Doctor redeeming all-access share code..."

ISSUE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/records/issue-pass" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $DOCTOR_ID_TOKEN" \
  -d '{
    "code": "'"$ALL_SHARE_CODE"'"
  }')

HTTP_CODE=$(echo "$ISSUE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$ISSUE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  ALL_PASS_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.passToken')
  print_success "All-access code redeemed successfully"
else
  print_error "Share code redemption failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

sleep 1

# ====================================
# Step 9: Doctor retrieves all patient records
# ====================================
print_step "Step 9: Doctor retrieving all patient records..."

RECORDS_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$API_URL/records" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $DOCTOR_ID_TOKEN" \
  -H "x-pass-token: $ALL_PASS_TOKEN")

HTTP_CODE=$(echo "$RECORDS_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RECORDS_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
  RECORD_COUNT=$(echo "$RESPONSE_BODY" | jq '.items | length')
  print_success "Retrieved $RECORD_COUNT record(s)"

  # Verify doctor can see all record types
  if [ "$RECORD_COUNT" -eq 3 ]; then
    print_success "All-access sharing working correctly - Doctor can see all 3 records"
    echo "$RESPONSE_BODY" | jq '.items[] | {type, notes}'
  else
    print_error "Expected 3 records, got $RECORD_COUNT"
    echo "$RESPONSE_BODY" | jq '.items[] | {id, type, notes}'
    exit 1
  fi
else
  print_error "Record retrieval failed (HTTP $HTTP_CODE)"
  echo "$RESPONSE_BODY" | jq '.'
  exit 1
fi

echo ""
echo "======================================"
echo -e "${GREEN}✓ Selective Sharing E2E Test Completed Successfully!${NC}"
echo "======================================"
echo ""
echo "Summary:"
echo "  • Patient logged in ($PATIENT2_EMAIL)"
echo "  • Doctor logged in ($DOCTOR1_EMAIL)"
echo "  • Patient uploaded 3 record types (PRESCRIPTION, LAB, VISIT_NOTES)"
echo "  • First share code limited to LAB only - Doctor could only see 1 LAB record ✓"
echo "  • Second share code allowed all types - Doctor could see all 3 records ✓"
echo "  • Selective record sharing feature validated successfully ✓"
echo ""
