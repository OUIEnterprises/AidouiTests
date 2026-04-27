# E2E Tests

End-to-end tests for the AIDOUI API, testing complete user flows and feature interactions.

## Prerequisites

1. **jq** - JSON processor for parsing API responses
   ```bash
   # macOS
   brew install jq

   # Linux
   sudo apt-get install jq
   ```

2. **Environment Configuration** - Edit `test/invoke/env.sh` to configure:
   - API URL (default: Beta environment)
   - API Key
   - AWS region and resource names
   - Test account credentials

3. **Test Accounts Setup** - Run the setup script **ONCE** to create test accounts:
   ```bash
   cd test/setup
   ./setup_test_accounts.sh
   ```

   This creates:
   - 2 Patient accounts (patient+1@example.com, patient+2@example.com)
   - 1 Doctor account (doctor+1@example.com)
   - 1 Laboratory account (lab+1@example.com)
   - 1 Pharmacy account (pharmacy+1@example.com)
   - 1 Hospital account (hospital+1@example.com)

   ⚠️ **Note:** Provider accounts (Doctor, Lab, Pharmacy, Hospital) require admin verification before they can be used in tests.

## Available Tests

### 1. Patient-Doctor Flow (`e2e_patient_doctor_flow.sh`)

Tests the complete workflow between a patient and a doctor using pre-existing test accounts:
- Patient login (patient+1@example.com)
- Patient generates share code with selective record types
- Validates provider self-access prevention (HTTP 403)
- Doctor login (doctor+1@example.com)
- Doctor redeems share code
- Doctor uploads lab result for patient
- Patient verifies the uploaded record

**Run:**
```bash
cd test/e2e
./e2e_patient_doctor_flow.sh
```

### 2. Selective Record Sharing (`e2e_selective_sharing.sh`)

Comprehensive test of the selective record sharing feature using pre-existing test accounts:
- Patient login (patient+2@example.com)
- Patient uploads multiple record types (PRESCRIPTION, LAB, VISIT_NOTES)
- Patient shares code with ONLY LAB access
- Doctor login (doctor+1@example.com)
- Doctor can only see LAB records (validates filtering)
- Patient shares code with ALL record types
- Doctor can now see all 3 records
- Validates that record type filtering works correctly

**Run:**
```bash
cd test/e2e
./e2e_selective_sharing.sh
```

## Test Output

Tests use color-coded output:
- 🔵 Blue arrow (==>) - Current step
- ✓ Green checkmark - Success
- ✗ Red X - Error
- ℹ Yellow info - Additional information

Example output:
```
==> Step 1: Signing up patient...
✓ Patient signed up successfully
ℹ Patient verification status: APPROVED
```

## Features Tested

### Patient-Doctor Flow
- [x] User authentication (login for patient and doctor)
- [x] Selective share code generation with recordTypes array
- [x] Provider self-access prevention (cannot redeem own codes)
- [x] Pass token redemption
- [x] Record upload with pass token
- [x] Record retrieval and verification

### Selective Sharing
- [x] User authentication (login for patient and doctor)
- [x] Multiple record type uploads (PRESCRIPTION, LAB, VISIT_NOTES)
- [x] Selective record type sharing (LAB only)
- [x] Record type filtering validation
- [x] All-access sharing (all record types)
- [x] Pass token with different scopes
- [x] Record access validation based on recordTypes

### Account Setup (One-time)
- [x] Patient account creation (via setup script)
- [x] Doctor account creation with license verification (via setup script)
- [x] Laboratory account creation (via setup script)
- [x] Pharmacy account creation (via setup script)
- [x] Hospital account creation (via setup script)

## Environment Variables

Key environment variables used (configured in `test/invoke/env.sh`):

```bash
API_URL="https://api.beta.aidoui.com/beta"
API_KEY="<your-api-key>"
AWS_REGION="eu-central-1"
```

## Recent Updates

### Test Account Management (2025)
- **Pre-existing test accounts**: E2E tests now use pre-existing accounts instead of creating new ones each run
- **One-time setup**: Added `setup_test_accounts.sh` script to create test accounts once
- **Faster test execution**: Tests no longer need to wait for account creation
- **Cleaner test data**: No accumulation of test accounts in the database
- Test accounts defined in `test/invoke/env.sh`

### Selective Record Sharing (2025)
- Added `recordTypes` parameter to share code generation
- Pass tokens now include scope limitations based on record types
- Providers can only access records within their granted scope
- Added e2e test specifically for selective sharing feature

### Provider Self-Access Prevention (2025)
- Providers cannot redeem their own access codes
- Returns HTTP 403 when attempted
- Prevents security loophole in the system
- Added validation in both frontend and backend

### Record Type Updates (2025)
- Updated from old types (REC/RX/LAB/XRAY) to new enum:
  - `PRESCRIPTION` - Prescription records
  - `LAB` - Lab results (including X-rays)
  - `VISIT_NOTES` - Doctor visit notes

## Troubleshooting

### Test fails with "jq: command not found"
Install jq using the commands in Prerequisites section.

### Test fails with "Invalid API key"
Update the `API_KEY` in `test/invoke/env.sh` with a valid key.

### Test fails with "Test file not found"
Ensure test fixtures exist in `test/fixtures/`:
- `TestLabResult.pdf`
- `TestLabResult.docx`

### Selective sharing test shows wrong record count
Verify that:
1. The patient successfully uploaded all 3 record types
2. The share code was created with correct recordTypes array
3. The pass token includes the correct scopes

## Running All Tests

To run all e2e tests sequentially:

```bash
cd test/e2e
for test in *.sh; do
  echo "Running $test..."
  ./"$test"
  echo ""
done
```

## Contributing

When adding new e2e tests:
1. Use the same color-coded output pattern
2. Include cleanup function for temp files
3. Add comprehensive error handling
4. Update this README with test description
5. Make the script executable: `chmod +x your_test.sh`
