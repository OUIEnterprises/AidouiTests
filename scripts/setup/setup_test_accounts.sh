#!/usr/bin/env bash
set -euo pipefail

# Source environment variables
source "$(dirname "$0")/../invoke/env.sh"

echo "======================================"
echo "Setup: Creating Test Accounts"
echo "======================================"
echo ""
echo "This script creates test accounts for E2E testing."
echo "Run this ONCE to set up your test environment."
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

print_warning() {
  echo -e "${YELLOW}⚠${NC} ${1}"
}

# ====================================
# Create Patient 1
# ====================================
print_step "Creating Patient 1: $PATIENT1_EMAIL"

SIGNUP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/signup" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "email": "'"$PATIENT1_EMAIL"'",
    "password": "'"$PATIENT1_PASS"'",
    "givenName": "Sarah",
    "familyName": "Johnson",
    "phoneNumber": "+15551234001",
    "role": "Patient"
  }')

HTTP_CODE=$(echo "$SIGNUP_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 201 ]; then
  print_success "Patient 1 created successfully"
elif [ "$HTTP_CODE" -eq 400 ]; then
  RESPONSE_BODY=$(echo "$SIGNUP_RESPONSE" | sed '$d')
  if echo "$RESPONSE_BODY" | grep -q "already exists"; then
    print_warning "Patient 1 already exists (skipping)"
  else
    print_error "Patient 1 creation failed: $RESPONSE_BODY"
  fi
else
  print_error "Patient 1 creation failed (HTTP $HTTP_CODE)"
  echo "$SIGNUP_RESPONSE" | sed '$d' | jq '.'
fi

sleep 1

# ====================================
# Create Patient 2
# ====================================
print_step "Creating Patient 2: $PATIENT2_EMAIL"

SIGNUP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/signup" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "email": "'"$PATIENT2_EMAIL"'",
    "password": "'"$PATIENT2_PASS"'",
    "givenName": "Michael",
    "familyName": "Chen",
    "phoneNumber": "+15551234002",
    "role": "Patient"
  }')

HTTP_CODE=$(echo "$SIGNUP_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 201 ]; then
  print_success "Patient 2 created successfully"
elif [ "$HTTP_CODE" -eq 400 ]; then
  RESPONSE_BODY=$(echo "$SIGNUP_RESPONSE" | sed '$d')
  if echo "$RESPONSE_BODY" | grep -q "already exists"; then
    print_warning "Patient 2 already exists (skipping)"
  else
    print_error "Patient 2 creation failed: $RESPONSE_BODY"
  fi
else
  print_error "Patient 2 creation failed (HTTP $HTTP_CODE)"
  echo "$SIGNUP_RESPONSE" | sed '$d' | jq '.'
fi

sleep 1

# ====================================
# Create Doctor 1
# ====================================
print_step "Creating Doctor 1: $DOCTOR1_EMAIL"

SIGNUP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/signup" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "email": "'"$DOCTOR1_EMAIL"'",
    "password": "'"$DOCTOR1_PASS"'",
    "givenName": "James",
    "familyName": "Smith",
    "phoneNumber": "+15559876001",
    "role": "Doctor",
    "licenseNumber": "MD123456",
    "specialty": "General Practice"
  }')

HTTP_CODE=$(echo "$SIGNUP_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 201 ]; then
  print_success "Doctor 1 created successfully"
  print_info "Note: Doctor account may need admin verification"
elif [ "$HTTP_CODE" -eq 400 ]; then
  RESPONSE_BODY=$(echo "$SIGNUP_RESPONSE" | sed '$d')
  if echo "$RESPONSE_BODY" | grep -q "already exists"; then
    print_warning "Doctor 1 already exists (skipping)"
  else
    print_error "Doctor 1 creation failed: $RESPONSE_BODY"
  fi
else
  print_error "Doctor 1 creation failed (HTTP $HTTP_CODE)"
  echo "$SIGNUP_RESPONSE" | sed '$d' | jq '.'
fi

sleep 1

# ====================================
# Create Lab 1
# ====================================
print_step "Creating Laboratory 1: $LAB1_EMAIL"

SIGNUP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/signup" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "email": "'"$LAB1_EMAIL"'",
    "password": "'"$LAB1_PASS"'",
    "givenName": "Quest",
    "familyName": "Diagnostics",
    "phoneNumber": "+15559876002",
    "role": "Laboratory",
    "licenseNumber": "LAB789012",
    "specialty": "Clinical Laboratory"
  }')

HTTP_CODE=$(echo "$SIGNUP_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 201 ]; then
  print_success "Laboratory 1 created successfully"
  print_info "Note: Lab account may need admin verification"
elif [ "$HTTP_CODE" -eq 400 ]; then
  RESPONSE_BODY=$(echo "$SIGNUP_RESPONSE" | sed '$d')
  if echo "$RESPONSE_BODY" | grep -q "already exists"; then
    print_warning "Laboratory 1 already exists (skipping)"
  else
    print_error "Laboratory 1 creation failed: $RESPONSE_BODY"
  fi
else
  print_error "Laboratory 1 creation failed (HTTP $HTTP_CODE)"
  echo "$SIGNUP_RESPONSE" | sed '$d' | jq '.'
fi

sleep 1

# ====================================
# Create Pharmacy 1
# ====================================
print_step "Creating Pharmacy 1: $PHARMACY1_EMAIL"

SIGNUP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/signup" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "email": "'"$PHARMACY1_EMAIL"'",
    "password": "'"$PHARMACY1_PASS"'",
    "givenName": "CVS",
    "familyName": "Pharmacy",
    "phoneNumber": "+15559876003",
    "role": "Pharmacy",
    "licenseNumber": "PHR345678",
    "specialty": "Retail Pharmacy"
  }')

HTTP_CODE=$(echo "$SIGNUP_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 201 ]; then
  print_success "Pharmacy 1 created successfully"
  print_info "Note: Pharmacy account may need admin verification"
elif [ "$HTTP_CODE" -eq 400 ]; then
  RESPONSE_BODY=$(echo "$SIGNUP_RESPONSE" | sed '$d')
  if echo "$RESPONSE_BODY" | grep -q "already exists"; then
    print_warning "Pharmacy 1 already exists (skipping)"
  else
    print_error "Pharmacy 1 creation failed: $RESPONSE_BODY"
  fi
else
  print_error "Pharmacy 1 creation failed (HTTP $HTTP_CODE)"
  echo "$SIGNUP_RESPONSE" | sed '$d' | jq '.'
fi

sleep 1

# ====================================
# Create Hospital 1
# ====================================
print_step "Creating Hospital 1: $HOSPITAL1_EMAIL"

SIGNUP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/signup" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "email": "'"$HOSPITAL1_EMAIL"'",
    "password": "'"$HOSPITAL1_PASS"'",
    "givenName": "City General",
    "familyName": "Hospital",
    "phoneNumber": "+15559876004",
    "role": "Hospital",
    "licenseNumber": "HSP901234",
    "specialty": "General Hospital"
  }')

HTTP_CODE=$(echo "$SIGNUP_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 201 ]; then
  print_success "Hospital 1 created successfully"
  print_info "Note: Hospital account may need admin verification"
elif [ "$HTTP_CODE" -eq 400 ]; then
  RESPONSE_BODY=$(echo "$SIGNUP_RESPONSE" | sed '$d')
  if echo "$RESPONSE_BODY" | grep -q "already exists"; then
    print_warning "Hospital 1 already exists (skipping)"
  else
    print_error "Hospital 1 creation failed: $RESPONSE_BODY"
  fi
else
  print_error "Hospital 1 creation failed (HTTP $HTTP_CODE)"
  echo "$SIGNUP_RESPONSE" | sed '$d' | jq '.'
fi

echo ""
echo "======================================"
echo -e "${GREEN}✓ Test Account Setup Complete!${NC}"
echo "======================================"
echo ""
echo "Created accounts:"
echo "  • 2 Patients: $PATIENT1_EMAIL, $PATIENT2_EMAIL"
echo "  • 1 Doctor: $DOCTOR1_EMAIL"
echo "  • 1 Laboratory: $LAB1_EMAIL"
echo "  • 1 Pharmacy: $PHARMACY1_EMAIL"
echo "  • 1 Hospital: $HOSPITAL1_EMAIL"
echo ""
echo -e "${YELLOW}⚠ IMPORTANT:${NC} Provider accounts (Doctor, Lab, Pharmacy, Hospital)"
echo "  may require admin verification before they can be used."
echo "  Please verify their status in the admin console."
echo ""
