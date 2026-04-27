# AIDOUI E2E Tests

End-to-end integration test suite for the AIDOUI API using Java, JUnit 5, and REST Assured.

## Overview

This test suite provides comprehensive API testing for the AIDOUI platform, covering:
- Authentication endpoints (login, profile management)
- Medical records endpoints (view, share, access control)
- Authorization and security validation
- Complete user workflows (patient → provider sharing flow)

## Technology Stack

- **Java 17**
- **JUnit 5** - Testing framework
- **REST Assured** - API testing library
- **AssertJ** - Fluent assertions
- **Maven** - Build and dependency management
- **Jackson** - JSON processing

## Prerequisites

- Java 17 or higher
- Maven 3.6+
- Access to AIDOUI Beta environment

## Project Structure

```
src/
├── main/java/com/aidoui/client/
│   └── model/           # API response models
└── test/
    ├── java/com/aidoui/e2e/
    │   ├── config/      # Test configuration
    │   └── *.java       # Test classes
    └── resources/
        └── test-*.properties  # Environment configs
```

## Configuration

Test configuration is environment-specific and loaded from `src/test/resources/test-{env}.properties`.

### Beta Environment (`test-beta.properties`)
```properties
api.url=https://api.beta.aidoui.com
api.key=YOUR_API_KEY
test.patient.email=patient+1@example.com
test.patient.password=YOUR_PASSWORD
test.doctor.email=doctor+1@example.com
test.doctor.password=YOUR_PASSWORD
```

### Running Tests Against Different Environments

```bash
# Beta (default)
mvn clean test

# Specify environment explicitly
mvn clean test -Denv=beta
```

## Running Tests

### Run all tests
```bash
mvn clean test
```

### Run specific test class
```bash
mvn test -Dtest=RecordsEndpointsTest
```

### Run specific test method
```bash
mvn test -Dtest=RecordsEndpointsTest#testPatientLogin
```

### Run tests with detailed logging
```bash
mvn test -X
```

## Test Coverage

### RecordsEndpointsTest
Complete records sharing workflow:
1. ✅ Patient login
2. ✅ Doctor login
3. ✅ Patient shares records (generates access code)
4. ✅ Doctor redeems code (gets pass token)
5. ✅ Doctor lists active passes (using Cognito JWT)
6. ✅ Doctor views patient records (using pass token)
7. ✅ Patient views own records (using Cognito JWT)

### Authorization Tests
- ✅ Missing API key rejection
- ✅ Invalid token rejection
- ✅ Correct token type enforcement (Cognito JWT vs Pass Token)

## Integration with CI/CD

### AWS CodePipeline Integration

This test suite is designed to run in the Beta deployment stage of AWS CodePipeline.

**buildspec.yml example:**
```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      java: corretto17

  pre_build:
    commands:
      - echo "Installing dependencies..."
      - mvn install -DskipTests

  build:
    commands:
      - echo "Running E2E tests against Beta..."
      - mvn test -Denv=beta

reports:
  e2e-tests:
    files:
      - 'target/surefire-reports/*.xml'
    file-format: 'JUNITXML'
```

### Test Results

Maven Surefire generates test reports in:
- `target/surefire-reports/` - JUnit XML reports
- `target/surefire-reports/*.txt` - Text summaries

## Writing New Tests

### Example Test Structure
```java
@Test
@Order(1)
@DisplayName("Should perform action successfully")
public void testAction() {
    given()
        .header("x-api-key", config.getApiKey())
        .header("Authorization", "Bearer " + token)
        .contentType(ContentType.JSON)
        .body(requestBody)
    .when()
        .post("/endpoint")
    .then()
        .statusCode(200)
        .body("field", equalTo("value"));
}
```

### Best Practices

1. **Use TestConfig** - Load all environment-specific values from configuration
2. **Descriptive Names** - Use `@DisplayName` for readable test reports
3. **Test Order** - Use `@Order` when tests depend on previous test state
4. **Assertions** - Use AssertJ for fluent, readable assertions
5. **Cleanup** - Clean up test data when needed (use `@AfterAll`)

## Debugging

### Enable REST Assured Logging
```java
@BeforeAll
public void setup() {
    RestAssured.enableLoggingOfRequestAndResponseIfValidationFails();
}
```

### View Request/Response Details
```java
given()
    .log().all()  // Log request
.when()
    .get("/endpoint")
.then()
    .log().all(); // Log response
```

## Common Issues

### "Unable to find test-{env}.properties"
- Ensure the properties file exists in `src/test/resources/`
- Check the environment name (default is `beta`)

### "Connection refused" or timeout
- Verify API URL is correct
- Check VPN/network connectivity to the environment
- Verify API is deployed and healthy

### "403 Forbidden"
- Check API key is correct and not expired
- Verify API key is properly configured in properties file

### "401 Unauthorized"
- Test account credentials may be incorrect
- Token may be expired (re-run tests from beginning)

## Roadmap

### Planned Enhancements
- [ ] Add tests for file upload (POST /records with multipart/form-data)
- [ ] Add tests for all provider types (Lab, Pharmacy, Hospital)
- [ ] Add performance/load tests
- [ ] Add test data seeding/cleanup utilities
- [ ] Add tests for error scenarios and edge cases
- [ ] Generate HTML test reports

## Contributing

When adding new tests:
1. Follow existing test structure and naming conventions
2. Update this README with new test coverage
3. Ensure tests are idempotent (can be run multiple times)
4. Add appropriate `@DisplayName` annotations
5. Use fluent assertions for readability

## Related Documentation

- [API Testing Guide](https://github.com/OUIEnterprises/AidouiDocumentation/blob/main/backend/TESTING-GUIDE.md)
- [Authentication API Docs](https://github.com/OUIEnterprises/AidouiDocumentation/blob/main/backend/AUTH-API.md)
- [Records API Flow](https://github.com/OUIEnterprises/AidouiDocumentation/blob/main/CodeSharingAndPassesFlow.md)

## License

Copyright © 2026 AIDOUI / OUI Enterprises
