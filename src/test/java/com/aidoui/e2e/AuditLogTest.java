package com.aidoui.e2e;

import com.aidoui.e2e.config.TestConfig;
import io.restassured.RestAssured;
import io.restassured.config.HttpClientConfig;
import io.restassured.config.RestAssuredConfig;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import org.junit.jupiter.api.*;

import java.util.concurrent.TimeUnit;
import java.util.List;
import java.util.Map;

import static io.restassured.RestAssured.*;
import static org.hamcrest.Matchers.*;
import static org.hamcrest.MatcherAssert.assertThat;

/**
 * E2E Test: Audit Logging (HIPAA Compliance)
 *
 * This test verifies that all medical record access is properly audited:
 * - Share code creation is logged
 * - Pass issuance (code redemption) is logged
 * - Record viewing is logged
 * - Record uploads are logged
 * - Patients can retrieve their audit logs
 *
 * Test Flow:
 * 1. Patient logs in
 * 2. Patient creates a share code (should create SHARE_CREATED audit entry)
 * 3. Doctor logs in
 * 4. Doctor redeems the share code (should create PASS_ISSUED audit entry)
 * 5. Doctor views patient records (should create VIEW_RECORDS audit entry)
 * 6. Patient retrieves audit log
 * 7. Verify all expected audit entries are present
 * 8. Verify audit entries contain required fields (IP address, user agent, timestamps)
 * 9. Cleanup: Revoke share code
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@DisplayName("E2E: Audit Logging (HIPAA Compliance)")
@Timeout(value = 60, unit = TimeUnit.SECONDS)
public class AuditLogTest {

    private TestConfig config;
    private String patientIdToken;
    private String doctorIdToken;
    private String shareCode;
    private String passToken;
    private String patientId;
    private long testStartTime;

    @BeforeAll
    public void setup() {
        config = TestConfig.getInstance();
        RestAssured.baseURI = config.getApiUrl();
        RestAssured.enableLoggingOfRequestAndResponseIfValidationFails();

        // Configure timeouts
        int timeoutMs = config.getRequestTimeout();
        RestAssured.config = RestAssuredConfig.config()
            .httpClient(HttpClientConfig.httpClientConfig()
                .setParam("http.connection.timeout", timeoutMs)
                .setParam("http.socket.timeout", timeoutMs)
                .setParam("http.connection-manager.timeout", timeoutMs));

        // Capture test start time for filtering audit logs
        testStartTime = System.currentTimeMillis();
    }

    @Test
    @Order(1)
    @DisplayName("Step 1: Patient should log in successfully")
    public void step1_patientLogin() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "email": "%s",
                            "password": "%s"
                        }
                        """, config.getPatientEmail(), config.getPatientPassword()))
                .when()
                .post("/login")
                .then()
                .statusCode(200)
                .body("idToken", notNullValue())
                .body("user.role", equalTo("Patient"))
                .body("user.userId", notNullValue())
                .extract().response();

        patientIdToken = response.path("idToken");
        patientId = response.path("user.userId");

        assertThat("Patient ID token should be present", patientIdToken, is(not(emptyString())));

        System.out.println("Patient logged in. Patient ID: " + patientId);
    }

    @Test
    @Order(2)
    @DisplayName("Step 2: Patient creates share code (triggers SHARE_CREATED audit log)")
    public void step2_createShareCode() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "purpose": "DOCTOR_VISIT",
                            "ttlSeconds": 7200,
                            "label": "E2E Audit Test - Doctor Visit",
                            "recordTypes": ["PRESCRIPTION", "LAB", "VISIT_NOTES"]
                        }
                        """)
                .when()
                .post("/records/share")
                .then()
                .statusCode(200)
                .body("code", notNullValue())
                .body("code", matchesPattern("[A-Z0-9]{6}"))
                .extract().response();

        shareCode = response.path("code");
        System.out.println("Created share code (should trigger SHARE_CREATED audit): " + shareCode);
    }

    @Test
    @Order(3)
    @DisplayName("Step 3: Doctor logs in")
    public void step3_doctorLogin() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "email": "%s",
                            "password": "%s"
                        }
                        """, config.getDoctorEmail(), config.getDoctorPassword()))
                .when()
                .post("/login")
                .then()
                .statusCode(200)
                .body("idToken", notNullValue())
                .body("user.role", equalTo("Doctor"))
                .extract().response();

        doctorIdToken = response.path("idToken");
        System.out.println("Doctor logged in");
    }

    @Test
    @Order(4)
    @DisplayName("Step 4: Doctor redeems share code (triggers PASS_ISSUED audit log)")
    public void step4_doctorRedeemsShareCode() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + doctorIdToken)
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "code": "%s"
                        }
                        """, shareCode))
                .when()
                .post("/records/issue-pass")
                .then()
                .statusCode(200)
                .body("passToken", notNullValue())
                .body("patientId", equalTo(patientId))
                .extract().response();

        passToken = response.path("passToken");
        System.out.println("Doctor redeemed share code (should trigger PASS_ISSUED audit)");
    }

    @Test
    @Order(5)
    @DisplayName("Step 5: Doctor views patient records (triggers VIEW_RECORDS audit log)")
    public void step5_doctorViewsRecords() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + passToken)
                .when()
                .get("/records")
                .then()
                .statusCode(200)
                .body("items", notNullValue())
                .extract().response();

        List<Map<String, Object>> items = response.path("items");
        System.out.println("Doctor viewed " + items.size() + " records (should trigger VIEW_RECORDS audit)");
    }

    @Test
    @Order(6)
    @DisplayName("Step 6: Patient retrieves audit log")
    public void step6_patientRetrievesAuditLog() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .when()
                .get("/records/access-log")
                .then()
                .statusCode(200)
                .body("logs", notNullValue())
                .body("logs", not(empty()))
                .extract().response();

        List<Map<String, Object>> logs = response.path("logs");
        System.out.println("Retrieved " + logs.size() + " audit log entries");

        // Print audit log entries for debugging
        for (Map<String, Object> log : logs) {
            System.out.println("  - Action: " + log.get("action") +
                             " | Timestamp: " + log.get("timestamp") +
                             " | Provider: " + log.get("providerId"));
        }
    }

    @Test
    @Order(7)
    @DisplayName("Step 7: Verify SHARE_CREATED audit entry exists")
    public void step7_verifyShareCreatedAudit() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .when()
                .get("/records/access-log")
                .then()
                .statusCode(200)
                .extract().response();

        List<Map<String, Object>> logs = response.path("logs");

        // Find SHARE_CREATED entry created during this test
        boolean foundShareCreated = logs.stream()
            .anyMatch(log -> {
                String action = (String) log.get("action");
                String shareCodeMasked = (String) log.get("shareCode");
                String timestamp = (String) log.get("timestamp");

                // Check if this is a SHARE_CREATED action from our test
                return "SHARE_CREATED".equals(action) &&
                       shareCodeMasked != null &&
                       shareCodeMasked.startsWith(shareCode.substring(0, 2)); // Masked code shows first 2 chars
            });

        assertThat("Audit log should contain SHARE_CREATED entry", foundShareCreated, is(true));

        System.out.println("✓ SHARE_CREATED audit entry verified");
    }

    @Test
    @Order(8)
    @DisplayName("Step 8: Verify PASS_ISSUED audit entry exists")
    public void step8_verifyPassIssuedAudit() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .when()
                .get("/records/access-log")
                .then()
                .statusCode(200)
                .extract().response();

        List<Map<String, Object>> logs = response.path("logs");

        // Find PASS_ISSUED entry created during this test
        boolean foundPassIssued = logs.stream()
            .anyMatch(log -> {
                String action = (String) log.get("action");
                String shareCodeMasked = (String) log.get("shareCode");

                return "PASS_ISSUED".equals(action) &&
                       shareCodeMasked != null &&
                       shareCodeMasked.startsWith(shareCode.substring(0, 2));
            });

        assertThat("Audit log should contain PASS_ISSUED entry", foundPassIssued, is(true));

        System.out.println("✓ PASS_ISSUED audit entry verified");
    }

    @Test
    @Order(9)
    @DisplayName("Step 9: Verify VIEW_RECORDS audit entry exists")
    public void step9_verifyViewRecordsAudit() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .when()
                .get("/records/access-log")
                .then()
                .statusCode(200)
                .extract().response();

        List<Map<String, Object>> logs = response.path("logs");

        // Find VIEW_RECORDS entry created during this test (should be recent)
        boolean foundViewRecords = logs.stream()
            .anyMatch(log -> {
                String action = (String) log.get("action");
                return "VIEW_RECORDS".equals(action);
            });

        assertThat("Audit log should contain VIEW_RECORDS entry", foundViewRecords, is(true));

        System.out.println("✓ VIEW_RECORDS audit entry verified");
    }

    @Test
    @Order(10)
    @DisplayName("Step 10: Verify audit entries contain required HIPAA fields")
    public void step10_verifyAuditFieldsCompleteness() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .when()
                .get("/records/access-log")
                .then()
                .statusCode(200)
                .extract().response();

        List<Map<String, Object>> logs = response.path("logs");

        // Find a recent audit entry (SHARE_CREATED, PASS_ISSUED, or VIEW_RECORDS)
        Map<String, Object> auditEntry = logs.stream()
            .filter(log -> {
                String action = (String) log.get("action");
                return "SHARE_CREATED".equals(action) ||
                       "PASS_ISSUED".equals(action) ||
                       "VIEW_RECORDS".equals(action);
            })
            .findFirst()
            .orElseThrow(() -> new AssertionError("No audit entry found"));

        // Verify required HIPAA fields
        assertThat("Audit entry must have patientId", auditEntry.get("patientId"), notNullValue());

        assertThat("Audit entry must have providerId", auditEntry.get("providerId"), notNullValue());

        assertThat("Audit entry must have providerRole", auditEntry.get("providerRole"), notNullValue());

        assertThat("Audit entry must have action", auditEntry.get("action"), notNullValue());

        assertThat("Audit entry must have timestamp", auditEntry.get("timestamp"), notNullValue());

        assertThat("Audit entry must have ipAddress for HIPAA compliance", auditEntry.get("ipAddress"), notNullValue());

        assertThat("Audit entry must have userAgent for HIPAA compliance", auditEntry.get("userAgent"), notNullValue());

        System.out.println("✓ Audit entry contains all required HIPAA fields");
    }

    @Test
    @Order(11)
    @DisplayName("Cleanup: Revoke share code")
    public void step11_cleanupRevokeShareCode() {
        given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .when()
                .delete("/records/share-codes/" + shareCode)
                .then()
                .statusCode(anyOf(equalTo(200), equalTo(404), equalTo(409))); // OK, not found, or already redeemed

        System.out.println("Cleanup complete - share code revoked");
    }

    @Nested
    @DisplayName("Security and Access Control")
    class SecurityScenarios {

        @Test
        @DisplayName("Doctor should NOT be able to view patient's audit log")
        public void doctorCannotViewPatientAuditLog() {
            Assumptions.assumeTrue(doctorIdToken != null, "Doctor not logged in");

            // Doctor should not have access to patient's audit log
            // This endpoint should be patient-only
            given()
                    .header("x-api-key", config.getApiKey())
                    .header("Authorization", "Bearer " + doctorIdToken)
                    .when()
                    .get("/records/access-log")
                    .then()
                    .statusCode(anyOf(equalTo(403), equalTo(401)));
        }

        @Test
        @DisplayName("Should reject access log request without authentication")
        public void shouldRejectUnauthenticatedAuditLogAccess() {
            given()
                    .header("x-api-key", config.getApiKey())
                    .when()
                    .get("/records/access-log")
                    .then()
                    .statusCode(401);
        }
    }

    @Nested
    @DisplayName("Audit Log Pagination and Filtering")
    class PaginationScenarios {

        @Test
        @DisplayName("Should support limit parameter for pagination")
        public void shouldSupportLimitParameter() {
            Assumptions.assumeTrue(patientIdToken != null, "Patient not logged in");

            Response response = given()
                    .header("x-api-key", config.getApiKey())
                    .header("Authorization", "Bearer " + patientIdToken)
                    .queryParam("limit", 2)
                    .when()
                    .get("/records/access-log")
                    .then()
                    .statusCode(200)
                    .body("logs", notNullValue())
                    .extract().response();

            List<Map<String, Object>> logs = response.path("logs");

            assertThat("Limit parameter should restrict number of results", logs.size(), lessThanOrEqualTo(2));
        }

        @Test
        @DisplayName("Should return empty array for patient with no audit history")
        public void shouldReturnEmptyForNoHistory() {
            Assumptions.assumeTrue(patientIdToken != null, "Patient not logged in");

            // Query with very recent timestamp filter (likely no results)
            long futureTimestamp = System.currentTimeMillis() + 10000;

            given()
                    .header("x-api-key", config.getApiKey())
                    .header("Authorization", "Bearer " + patientIdToken)
                    .queryParam("from", futureTimestamp)
                    .when()
                    .get("/records/access-log")
                    .then()
                    .statusCode(200)
                    .body("logs", notNullValue())
                    .body("logs", hasSize(0));
        }
    }
}
