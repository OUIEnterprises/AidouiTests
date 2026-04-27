#!/bin/bash

# Test JWT Verification Security
# This script tests the authorizer's JWKS signature verification with various token scenarios

set -e
set -u  # Treat unset variables as an error EXCEPT for our token checks

source "$(dirname "$0")/env.sh"

# Allow ID_TOKEN to be unset for some tests
set +u

echo "=========================================="
echo "JWT Verification Security Test"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
PASSED=0
FAILED=0

# Helper function to test endpoint
test_endpoint() {
    local test_name="$1"
    local token="$2"
    local should_succeed="$3"

    echo -n "Testing: $test_name... "

    response=$(curl -s -w "\n%{http_code}" -X GET "$API_URL/user" \
        -H "Authorization: Bearer $token" \
        -H "x-api-key: $API_KEY")

    http_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | sed '$d')

    if [ "$should_succeed" = "true" ]; then
        # Should succeed (200)
        if [ "$http_code" = "200" ]; then
            echo -e "${GREEN}✓ PASS${NC} (HTTP $http_code)"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}✗ FAIL${NC} (Expected 200, got $http_code)"
            echo "Response: $body"
            ((FAILED++))
            return 1
        fi
    else
        # Should fail (401 or 403)
        if [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
            echo -e "${GREEN}✓ PASS${NC} (HTTP $http_code - correctly rejected)"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}✗ FAIL${NC} (Expected 401/403, got $http_code)"
            echo "Response: $body"
            ((FAILED++))
            return 1
        fi
    fi
}

# Test 1: Valid ID Token (should succeed)
echo "=========================================="
echo "Test 1: Valid ID Token"
echo "=========================================="
if [ -z "$ID_TOKEN" ]; then
    echo -e "${YELLOW}⚠ SKIP${NC} - No ID_TOKEN set. Run test-auth-endpoints.sh first to login."
    echo ""
else
    test_endpoint "Valid ID Token" "$ID_TOKEN" "true"
    echo ""
fi

# Test 2: Malformed Token (should fail)
echo "=========================================="
echo "Test 2: Malformed Token"
echo "=========================================="
test_endpoint "Malformed token" "not.a.valid.jwt.token.at.all" "false"
echo ""

# Test 3: Invalid Base64 (should fail)
echo "=========================================="
echo "Test 3: Invalid Base64 Encoding"
echo "=========================================="
test_endpoint "Invalid base64" "invalid-base64!@#$%^&*()" "false"
echo ""

# Test 4: Valid JWT Structure but Invalid Signature (should fail)
echo "=========================================="
echo "Test 4: Valid Structure, Invalid Signature"
echo "=========================================="
# This is a real JWT structure but with a fake signature
FAKE_JWT="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.fakesignaturefakesignaturefakesignaturefakesignature"
test_endpoint "Fake signature" "$FAKE_JWT" "false"
echo ""

# Test 5: Missing Token (should fail)
echo "=========================================="
echo "Test 5: Missing Authorization Header"
echo "=========================================="
echo -n "Testing: No token provided... "
response=$(curl -s -w "\n%{http_code}" -X GET "$API_URL/user" \
    -H "x-api-key: $API_KEY")
http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
    echo -e "${GREEN}✓ PASS${NC} (HTTP $http_code - correctly rejected)"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC} (Expected 401/403, got $http_code)"
    echo "Response: $body"
    ((FAILED++))
fi
echo ""

# Test 6: Empty Bearer Token (should fail)
echo "=========================================="
echo "Test 6: Empty Bearer Token"
echo "=========================================="
test_endpoint "Empty token" "" "false"
echo ""

# Test 7: Token with 'Bearer ' prefix (should still work with valid token)
echo "=========================================="
echo "Test 7: Proper Bearer Format (Valid Token)"
echo "=========================================="
if [ -z "$ID_TOKEN" ]; then
    echo -e "${YELLOW}⚠ SKIP${NC} - No ID_TOKEN set."
    echo ""
else
    # The curl command already adds 'Bearer ' prefix, so this tests the normal flow
    test_endpoint "Bearer prefix handling" "$ID_TOKEN" "true"
    echo ""
fi

# Test 8: Expired Token (manual test - requires generating an expired token)
echo "=========================================="
echo "Test 8: Expired Token"
echo "=========================================="
echo -e "${YELLOW}⚠ MANUAL TEST REQUIRED${NC}"
echo "To test expired tokens:"
echo "1. Wait for your current ID token to expire (typically 1 hour)"
echo "2. Try using the expired token - it should be rejected with 401"
echo "3. Or modify token exp claim manually and resign with fake key (should fail signature check)"
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All JWT verification tests passed!${NC}"
    echo ""
    echo "Security Status:"
    echo "✓ Valid tokens are accepted"
    echo "✓ Malformed tokens are rejected"
    echo "✓ Invalid signatures are rejected"
    echo "✓ Missing tokens are rejected"
    echo "✓ Empty tokens are rejected"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed. JWT verification may have security issues!${NC}"
    echo ""
    exit 1
fi
