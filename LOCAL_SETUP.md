# Local Setup and Testing Guide

This guide explains how to set up and run the AIDOUI E2E tests locally against the Beta environment.

## Prerequisites

### 1. Install Java 17+
```bash
# macOS (using Homebrew)
brew install openjdk@17

# Verify installation
java -version
```

### 2. Install Maven
```bash
# macOS (using Homebrew)
brew install maven

# Verify installation
mvn -version
```

### 3. Install jq (for bash scripts)
```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq
```

### 4. Clone the Repository
```bash
git clone git@github.com:OUIEnterprises/AidouiTests.git
cd AidouiTests
```

## Configuration

### Java Tests Configuration

The Java tests use properties files for environment configuration:

**File**: `src/test/resources/test-beta.properties`

```properties
# Beta Environment Configuration
api.url=https://api.beta.aidoui.com
api.key=YOUR_API_KEY_HERE
api.timeout=30000

# Test Account Credentials
test.patient.email=patient+1@example.com
test.patient.password=YOUR_PASSWORD

test.doctor.email=doctor+1@example.com
test.doctor.password=YOUR_PASSWORD
```

**⚠️ Important**: Get the actual API key and passwords from:
- API Key: AWS Console → API Gateway → AIDOUI Beta → API Keys
- Passwords: Check `AidouiCDK/test/invoke/env.sh` or AWS Cognito console

### Bash Scripts Configuration

The bash scripts use a shared environment file:

**File**: `scripts/invoke/env.sh`

```bash
export API_URL="https://api.beta.aidoui.com"
export API_KEY="YOUR_API_KEY_HERE"

export PATIENT1_EMAIL="patient+1@example.com"
export PATIENT1_PASS="YOUR_PASSWORD"

export DOCTOR1_EMAIL="doctor+1@example.com"
export DOCTOR1_PASS="YOUR_PASSWORD"
```

## Running Tests Locally

### Option 1: Java/JUnit Tests (Recommended)

#### Run All Tests
```bash
mvn clean test
```

#### Run Specific Test Class
```bash
mvn test -Dtest=RecordsEndpointsTest
```

#### Run Specific Test Method
```bash
mvn test -Dtest=RecordsEndpointsTest#testPatientLogin
```

#### Run with Verbose Output
```bash
mvn test -X
```

#### Test Execution Flow:
1. Maven downloads dependencies (first run only)
2. JUnit executes tests in order (@Order annotation)
3. REST Assured makes HTTP requests to Beta API
4. Assertions validate responses
5. Test report generated in `target/surefire-reports/`

**View Test Reports:**
```bash
# Terminal summary
cat target/surefire-reports/*.txt

# JUnit XML (for CI/CD)
ls target/surefire-reports/TEST-*.xml
```

### Option 2: Bash Scripts

The bash scripts provide quick smoke tests and manual verification.

#### Setup (One-time)
```bash
# Create test accounts in Beta (if not already created)
cd scripts/setup
./setup_test_accounts.sh
```

#### Run Individual Tests
```bash
# Comprehensive records workflow
cd scripts/invoke
./test-records-endpoints.sh

# Authentication endpoints
./test-auth-endpoints.sh

# Security/JWT validation
./run-security-tests.sh
```

#### Run E2E Flows
```bash
cd scripts/e2e

# Patient-Doctor complete workflow
./e2e_patient_doctor_flow.sh

# Selective record sharing test
./e2e_selective_sharing.sh

# Frontend integration test
./e2e_frontend_integration.sh
```

## Troubleshooting

### Java Tests

#### "Unable to find test-beta.properties"
- Ensure file exists: `src/test/resources/test-beta.properties`
- Check file permissions: `chmod 644 src/test/resources/test-beta.properties`

#### "Connection refused" or timeout errors
- Verify Beta API is accessible: `curl https://api.beta.aidoui.com`
- Check VPN/network connectivity
- Verify API URL in properties file (no trailing slash)

#### "403 Forbidden"
- Verify API key is correct and not expired
- Get fresh API key from AWS Console if needed

#### "401 Unauthorized"
- Test account credentials may be wrong
- Password may have been changed by other tests
- Reset password in Cognito console or re-run setup script

#### Maven build fails
```bash
# Clean and rebuild
mvn clean install

# Skip tests temporarily
mvn clean install -DskipTests

# Force update dependencies
mvn clean install -U
```

### Bash Scripts

#### "jq: command not found"
```bash
brew install jq
```

#### "Permission denied"
```bash
# Make scripts executable
chmod +x scripts/**/*.sh
```

#### "API_URL not set"
- Ensure you're sourcing `env.sh`:
```bash
cd scripts/invoke
source ./env.sh
./test-records-endpoints.sh
```

#### Tests fail inconsistently
- Test accounts may be in use by other processes
- Wait a few minutes and retry
- Check if Beta API is healthy: `aws codepipeline get-pipeline-state --name AidouiPipeline --region us-east-1`

## Development Workflow

### 1. Make Changes to Tests
Edit test files in `src/test/java/com/aidoui/e2e/`

### 2. Run Tests Locally
```bash
mvn clean test
```

### 3. Debug Failed Tests
```bash
# Run with detailed logging
mvn test -X -Dtest=YourTest

# Add logging in test code:
System.out.println("Debug: " + variable);
```

### 4. Commit and Push
```bash
git add .
git commit -m "Add new test for feature X"
git push
```

### 5. Verify in Pipeline
- Push triggers CodePipeline
- Tests run automatically in Beta stage
- Check CodeBuild console for results

## Test Data Management

### View Test Accounts
```bash
# List users in Cognito
aws cognito-idp list-users \
  --user-pool-id eu-central-1_l0zH51Kac \
  --region eu-central-1

# Check doctor's groups
aws cognito-idp admin-list-groups-for-user \
  --user-pool-id eu-central-1_l0zH51Kac \
  --username doctor+1@example.com \
  --region eu-central-1
```

### Reset Test Data
```bash
# Delete all passes for doctor
# (Use AWS Console → DynamoDB → Passes table → Scan with entityId filter)

# Reset patient records
# (Use AWS Console → S3 → Records bucket → Delete test files)
```

### Create Additional Test Accounts
Edit `scripts/setup/setup_test_accounts.sh` to add more accounts.

## IDE Integration

### IntelliJ IDEA
1. Open project: `File → Open → AidouiTests/pom.xml`
2. Wait for Maven import to complete
3. Right-click test class → Run
4. View results in Run window

### VS Code
1. Install "Extension Pack for Java"
2. Open project folder
3. Click "Run Test" above test methods
4. View results in Test Explorer

### Eclipse
1. Import Maven project: `File → Import → Maven → Existing Maven Projects`
2. Select AidouiTests folder
3. Right-click test → Run As → JUnit Test

## Environment-Specific Testing

### Switch Environments
```bash
# Test against different environment
mvn test -Denv=gamma  # When gamma.properties is added
mvn test -Denv=prod   # For production smoke tests (carefully!)
```

### Add New Environment
1. Create `src/test/resources/test-{env}.properties`
2. Update API URL and credentials
3. Run: `mvn test -Denv={env}`

## Best Practices

1. **Always run tests locally** before pushing
2. **Keep credentials secure** - never commit passwords
3. **Use test accounts only** - never test against production with real user data
4. **Clean up test data** - delete temporary records after manual testing
5. **Check test reports** - review failures before re-running
6. **Update documentation** - keep this guide current with changes

## Quick Reference

```bash
# Complete setup from scratch
git clone git@github.com:OUIEnterprises/AidouiTests.git
cd AidouiTests
# Edit src/test/resources/test-beta.properties (add API key & passwords)
mvn clean test

# Daily development
mvn test                          # Run all tests
mvn test -Dtest=RecordsEndpointsTest  # Run one class
git add . && git commit -m "msg" && git push  # Deploy

# Troubleshooting
mvn clean install -U              # Force refresh
./scripts/invoke/test-records-endpoints.sh  # Quick bash test
aws cognito-idp list-users --user-pool-id eu-central-1_l0zH51Kac --region eu-central-1  # Check accounts
```

## Getting Help

- **Test failures**: Check `target/surefire-reports/` for detailed errors
- **API issues**: Check CloudWatch Logs for Lambda execution logs
- **Authentication issues**: Verify Cognito user status in AWS Console
- **Documentation**: See `README.md` for full test suite documentation

## Next Steps

After successful local testing:
1. Tests will run automatically in CodePipeline for Beta deployments
2. Pipeline fails if tests fail (prevents broken code from reaching Prod)
3. Test reports available in CodeBuild console
4. Add more tests as new features are developed

---

**Questions?** Check the main [README.md](README.md) or [PIPELINE_INTEGRATION.md](PIPELINE_INTEGRATION.md) for more details.
