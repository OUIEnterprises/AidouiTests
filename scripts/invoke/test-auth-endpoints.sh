#!/usr/bin/env bash

# Test script for Phase 0 Auth Endpoints
# Tests: GET /user, PUT /user, POST /refresh-token, POST /change-password

set -euo pipefail

# Load environment variables
source "$(dirname "$0")/env.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Testing AIDOUI Auth Endpoints"
echo "Environment: ${API_URL}"
echo "========================================="
echo ""

# Use pre-existing patient account
TEST_EMAIL="$PATIENT1_EMAIL"
TEST_PASSWORD="$PATIENT1_PASS"
TEST_ROLE="$PATIENT1_ROLE"

echo -e "${YELLOW}Step 1: Logging in to get tokens${NC}"
read -r ACCESS_TOKEN ID_TOKEN REFRESH_TOKEN EXPIRES_IN <<<$(curl -s -X POST "$API_URL/login" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\"
  }" | jq -r '.accessToken, .idToken, .refreshToken, .expiresIn')

if [ "$ID_TOKEN" == "null" ] || [ -z "$ID_TOKEN" ]; then
    echo -e "${RED}Error: Failed to get ID token${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Login successful${NC}"
echo "  ID Token: ${ID_TOKEN:0:20}..."
echo "  Expires in: ${EXPIRES_IN}s"
echo ""

# Test 1: GET /user
echo "========================================="
echo -e "${YELLOW}Test 1: GET /user (Retrieve Profile)${NC}"
echo "========================================="

read -r SUB EMAIL ROLE <<<$(curl -s -X GET "$API_URL/user" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "x-api-key: $API_KEY" | jq -r '.sub, .email, .role')

echo "  User ID: $SUB"
echo "  Email: $EMAIL"
echo "  Role: $ROLE"

if [ "$EMAIL" == "$TEST_EMAIL" ] && [ "$ROLE" == "$TEST_ROLE" ]; then
    echo -e "${GREEN}✓ GET /user passed${NC}"
else
    echo -e "${RED}✗ GET /user failed - Email or role mismatch${NC}"
    exit 1
fi

echo ""

# Test 2: PUT /user
echo "========================================="
echo -e "${YELLOW}Test 2: PUT /user (Update Profile)${NC}"
echo "========================================="

NEW_PHONE="+9876543210"
RESPONSE=$(curl -s -X PUT "$API_URL/user" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "{\"phoneNumber\": \"$NEW_PHONE\"}")

MESSAGE=$(echo "$RESPONSE" | jq -r '.message')
UPDATED_FIELDS=$(echo "$RESPONSE" | jq -r '(.updatedFields | length)')

echo "  $MESSAGE"
echo "  Fields updated: $UPDATED_FIELDS"

if [ "$UPDATED_FIELDS" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✓ PUT /user passed - Profile updated${NC}"
else
    echo -e "${RED}✗ PUT /user failed - No fields updated${NC}"
    exit 1
fi

# Verify the update persisted
echo -e "${YELLOW}Verifying update persisted...${NC}"
UPDATED_PHONE=$(curl -s -X GET "$API_URL/user" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "x-api-key: $API_KEY" | jq -r .phoneNumber)

if [ "$UPDATED_PHONE" == "$NEW_PHONE" ]; then
    echo -e "${GREEN}✓ Update verification passed - Phone: $UPDATED_PHONE${NC}"
else
    echo -e "${RED}✗ Update verification failed - Phone: $UPDATED_PHONE (expected: $NEW_PHONE)${NC}"
    exit 1
fi

echo ""

# Test 3: PUT /user with immutable field (should fail or be ignored)
echo "========================================="
echo -e "${YELLOW}Test 3: PUT /user (Immutable field protection)${NC}"
echo "========================================="

UPDATED_COUNT=$(curl -s -X PUT "$API_URL/user" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"email": "hacker@evil.com", "role": "Doctor"}' | jq -r '.updatedFields | length // 0')

echo "  Fields updated: $UPDATED_COUNT"

if [ "$UPDATED_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ Immutable field protection passed${NC}"
else
    echo -e "${RED}✗ Immutable field protection failed - Fields were updated!${NC}"
    exit 1
fi

echo ""

# Test 4: POST /refresh-token
echo "========================================="
echo -e "${YELLOW}Test 4: POST /refresh-token${NC}"
echo "========================================="

read -r NEW_ACCESS_TOKEN NEW_ID_TOKEN NEW_EXPIRES <<<$(curl -s -X POST "$API_URL/refresh-token" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "{\"refreshToken\": \"$REFRESH_TOKEN\"}" | jq -r '.accessToken, .idToken, .expiresIn')

echo "  New ID Token: ${NEW_ID_TOKEN:0:20}..."
echo "  Expires in: ${NEW_EXPIRES}s"

if [ "$NEW_ID_TOKEN" != "null" ] && [ -n "$NEW_ID_TOKEN" ] && [ "$NEW_ID_TOKEN" != "$ID_TOKEN" ]; then
    echo -e "${GREEN}✓ POST /refresh-token passed - New tokens received${NC}"
else
    echo -e "${RED}✗ POST /refresh-token failed - Invalid tokens${NC}"
    exit 1
fi

# Verify new token works
echo -e "${YELLOW}Verifying new token works...${NC}"
TOKEN_EMAIL=$(curl -s -X GET "$API_URL/user" \
  -H "Authorization: Bearer $NEW_ID_TOKEN" \
  -H "x-api-key: $API_KEY" | jq -r .email)

if [ "$TOKEN_EMAIL" == "$TEST_EMAIL" ]; then
    echo -e "${GREEN}✓ New token verification passed${NC}"
else
    echo -e "${RED}✗ New token verification failed${NC}"
    exit 1
fi

echo ""

# Test 5: POST /change-password
echo "========================================="
echo -e "${YELLOW}Test 5: POST /change-password${NC}"
echo "========================================="

NEW_PASSWORD="TempTestPass456!"
CHANGE_MESSAGE=$(curl -s -X POST "$API_URL/change-password" \
  -H "Authorization: Bearer $NEW_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "{
    \"oldPassword\": \"$TEST_PASSWORD\",
    \"newPassword\": \"$NEW_PASSWORD\"
  }" | jq -r .message)

echo "  $CHANGE_MESSAGE"

if [[ "$CHANGE_MESSAGE" == *"success"* ]]; then
    echo -e "${GREEN}✓ POST /change-password passed${NC}"
else
    echo -e "${RED}✗ POST /change-password failed${NC}"
    exit 1
fi

# Verify new password works
echo -e "${YELLOW}Verifying new password works...${NC}"
NEW_LOGIN_TOKEN=$(curl -s -X POST "$API_URL/login" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$NEW_PASSWORD\"
  }" | jq -r .idToken)

if [ "$NEW_LOGIN_TOKEN" != "null" ] && [ -n "$NEW_LOGIN_TOKEN" ]; then
    echo -e "${GREEN}✓ New password verification passed${NC}"
else
    echo -e "${RED}✗ New password verification failed${NC}"
    exit 1
fi

echo ""

# Test 6: POST /change-password with wrong old password (should fail)
echo "========================================="
echo -e "${YELLOW}Test 6: POST /change-password (Wrong old password)${NC}"
echo "========================================="

NEW_LOGIN_ACCESS_TOKEN=$(curl -s -X POST "$API_URL/login" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$NEW_PASSWORD\"
  }" | jq -r .accessToken)

ERROR_MESSAGE=$(curl -s -X POST "$API_URL/change-password" \
  -H "Authorization: Bearer $NEW_LOGIN_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "oldPassword": "WrongPassword123!",
    "newPassword": "AnotherPass789!"
  }' | jq -r .error)

echo "  Error: $ERROR_MESSAGE"

if [[ "$ERROR_MESSAGE" == *"incorrect"* ]]; then
    echo -e "${GREEN}✓ Wrong password protection passed${NC}"
else
    echo -e "${RED}✗ Wrong password protection failed - Should have been rejected${NC}"
    exit 1
fi

echo ""

# Restore original password
echo -e "${YELLOW}Restoring original password...${NC}"
RESTORE_MESSAGE=$(curl -s -X POST "$API_URL/change-password" \
  -H "Authorization: Bearer $NEW_LOGIN_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d "{
    \"oldPassword\": \"$NEW_PASSWORD\",
    \"newPassword\": \"$TEST_PASSWORD\"
  }" | jq -r .message)

if [[ "$RESTORE_MESSAGE" == *"success"* ]]; then
    echo -e "${GREEN}✓ Password restored${NC}"
else
    echo -e "${RED}✗ Warning: Failed to restore original password${NC}"
fi

echo ""
echo "========================================="
echo -e "${GREEN}ALL TESTS PASSED! ✓${NC}"
echo "========================================="
echo ""
echo "Summary:"
echo "  ✓ GET /user - Profile retrieval"
echo "  ✓ PUT /user - Profile update (mutable fields)"
echo "  ✓ PUT /user - Immutable field protection"
echo "  ✓ POST /refresh-token - Token refresh"
echo "  ✓ POST /refresh-token - New token validation"
echo "  ✓ POST /change-password - Password change"
echo "  ✓ POST /change-password - New password login"
echo "  ✓ POST /change-password - Wrong password rejection"
echo ""
echo "Test account: $TEST_EMAIL"
echo "Environment: $API_URL"
echo ""
