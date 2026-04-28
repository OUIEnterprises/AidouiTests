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

import static io.restassured.RestAssured.*;
import static org.assertj.core.api.Assertions.*;
import static org.hamcrest.Matchers.*;

/**
 * E2E Test: Share Code Management
 *
 * This test covers patient-controlled share code management including:
 * - Creating multiple share codes with different purposes and TTLs
 * - Listing all active share codes
 * - Revoking specific share codes
 * - Verifying revoked codes cannot be redeemed
 *
 * Test Flow:
 * 1. Patient logs in
 * 2. Patient creates multiple share codes
 * 3. Patient lists active share codes
 * 4. Patient revokes a specific share code
 * 5. Verify the revoked code no longer appears in active codes
 * 6. Doctor attempts to redeem revoked code (should fail)
 * 7. Doctor successfully redeems non-revoked code
 * 8. Cleanup: Revoke remaining codes
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@DisplayName("E2E: Share Code Management")
@Timeout(value = 45, unit = TimeUnit.SECONDS)
public class ShareCodeManagementTest {

    private TestConfig config;
    private String patientIdToken;
    private String doctorIdToken;
    private String shareCode1;  // Will be revoked
    private String shareCode2;  // Will remain active
    private String shareCode3;  // For additional testing

    @BeforeAll
    public void setup() {
        config = TestConfig.getInstance();
        RestAssured.baseURI = config.getApiUrl();
        RestAssured.enableLoggingOfRequestAndResponseIfValidationFails();

        // Configure timeouts to prevent tests from hanging indefinitely
        int timeoutMs = config.getRequestTimeout();
        RestAssured.config = RestAssuredConfig.config()
            .httpClient(HttpClientConfig.httpClientConfig()
                .setParam("http.connection.timeout", timeoutMs)
                .setParam("http.socket.timeout", timeoutMs)
                .setParam("http.connection-manager.timeout", timeoutMs));
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
                .extract().response();

        patientIdToken = response.path("idToken");
        assertThat(patientIdToken)
                .as("Patient ID token should be present")
                .isNotEmpty();
    }

    @Test
    @Order(2)
    @DisplayName("Step 2: Patient creates share code #1 (for pharmacy)")
    public void step2_createShareCode1() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "purpose": "PHARMACY_FILL",
                            "ttlSeconds": 7200,
                            "label": "E2E Test - Pharmacy (Will be revoked)",
                            "recordTypes": ["PRESCRIPTION"]
                        }
                        """)
                .when()
                .post("/records/share")
                .then()
                .statusCode(200)
                .body("code", notNullValue())
                .body("code", matchesPattern("[A-Z0-9]{6}"))
                .extract().response();

        shareCode1 = response.path("code");
        System.out.println("Created share code 1: " + shareCode1);
    }

    @Test
    @Order(3)
    @DisplayName("Step 3: Patient creates share code #2 (for doctor)")
    public void step3_createShareCode2() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "purpose": "DOCTOR_VISIT",
                            "ttlSeconds": 3600,
                            "label": "E2E Test - Doctor Visit",
                            "recordTypes": ["PRESCRIPTION", "LAB", "VISIT_NOTES"]
                        }
                        """)
                .when()
                .post("/records/share")
                .then()
                .statusCode(200)
                .body("code", notNullValue())
                .extract().response();

        shareCode2 = response.path("code");
        System.out.println("Created share code 2: " + shareCode2);
    }

    @Test
    @Order(4)
    @DisplayName("Step 4: Patient creates share code #3 (for lab)")
    public void step4_createShareCode3() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "purpose": "LAB_ACCESS",
                            "ttlSeconds": 1800,
                            "label": "E2E Test - Lab Access",
                            "recordTypes": ["LAB"]
                        }
                        """)
                .when()
                .post("/records/share")
                .then()
                .statusCode(200)
                .body("code", notNullValue())
                .extract().response();

        shareCode3 = response.path("code");
        System.out.println("Created share code 3: " + shareCode3);
    }

    @Test
    @Order(5)
    @DisplayName("Step 5: Patient lists all active share codes")
    public void step5_listActiveShareCodes() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .when()
                .get("/records/share-codes")
                .then()
                .statusCode(200)
                .body("shareCodes", notNullValue())
                .body("shareCodes.size()", greaterThanOrEqualTo(3))
                .body("count", greaterThanOrEqualTo(3))
                .extract().response();

        List<String> codes = response.path("shareCodes.code");
        System.out.println("Active share codes: " + codes);

        assertThat(codes)
                .as("All three created codes should be in the list")
                .contains(shareCode1, shareCode2, shareCode3);

        // Verify structure of returned share codes
        response.then()
                .body("shareCodes[0].code", notNullValue())
                .body("shareCodes[0].purpose", notNullValue())
                .body("shareCodes[0].expiresAt", notNullValue())
                .body("shareCodes[0].createdAt", notNullValue());
    }

    @Test
    @Order(6)
    @DisplayName("Step 6: Patient revokes share code #1")
    public void step6_revokeShareCode1() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .when()
                .delete("/records/share-codes/" + shareCode1)
                .then()
                .statusCode(200)
                .body("message", notNullValue())
                .body("code", equalTo(shareCode1))
                .extract().response();

        String message = response.path("message");
        System.out.println("Revocation response: " + message);

        assertThat(message)
                .as("Revocation message should confirm success")
                .containsIgnoringCase("revoked");
    }

    @Test
    @Order(7)
    @DisplayName("Step 7: Verify revoked code no longer appears in active codes")
    public void step7_verifyRevokedCodeNotInList() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .when()
                .get("/records/share-codes")
                .then()
                .statusCode(200)
                .body("shareCodes", notNullValue())
                .extract().response();

        List<String> codes = response.path("shareCodes.code");
        System.out.println("Active codes after revocation: " + codes);

        assertThat(codes)
                .as("Revoked code should not be in active codes")
                .doesNotContain(shareCode1);

        assertThat(codes)
                .as("Non-revoked codes should still be in the list")
                .contains(shareCode2, shareCode3);
    }

    @Test
    @Order(8)
    @DisplayName("Step 8: Doctor logs in")
    public void step8_doctorLogin() {
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
    }

    @Test
    @Order(9)
    @DisplayName("Step 9: Doctor attempts to redeem revoked code - should fail")
    public void step9_doctorCannotRedeemRevokedCode() {
        given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + doctorIdToken)
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "code": "%s"
                        }
                        """, shareCode1))
                .when()
                .post("/records/issue-pass")
                .then()
                .statusCode(anyOf(equalTo(404), equalTo(410)))  // Not found or Gone
                .body("message", notNullValue());
    }

    @Test
    @Order(10)
    @DisplayName("Step 10: Doctor successfully redeems non-revoked code")
    public void step10_doctorRedeemsActiveCode() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + doctorIdToken)
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "code": "%s"
                        }
                        """, shareCode2))
                .when()
                .post("/records/issue-pass")
                .then()
                .statusCode(200)
                .body("passToken", notNullValue())
                .body("patientId", notNullValue())
                .extract().response();

        String passToken = response.path("passToken");
        System.out.println("Successfully redeemed active code, pass token: " + passToken);
    }

    @Test
    @Order(11)
    @DisplayName("Cleanup: Revoke remaining share codes")
    public void step11_cleanupRevokeRemainingCodes() {
        // Revoke code 3 (code 2 was already consumed in redemption)
        given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .when()
                .delete("/records/share-codes/" + shareCode3)
                .then()
                .statusCode(200);

        System.out.println("Cleanup complete - all test codes revoked or consumed");
    }

    @Nested
    @DisplayName("Error Scenarios")
    class ErrorScenarios {

        @Test
        @DisplayName("Should reject revocation of non-existent code")
        public void shouldRejectNonExistentCodeRevocation() {
            given()
                    .header("x-api-key", config.getApiKey())
                    .header("Authorization", "Bearer " + patientIdToken)
                    .when()
                    .delete("/records/share-codes/XXXXXX")
                    .then()
                    .statusCode(404)
                    .body("message", notNullValue());
        }

        @Test
        @DisplayName("Should reject double revocation of same code")
        public void shouldRejectDoubleRevocation() {
            Assumptions.assumeTrue(shareCode1 != null, "Share code 1 not available");

            // Try to revoke the already-revoked code again
            given()
                    .header("x-api-key", config.getApiKey())
                    .header("Authorization", "Bearer " + patientIdToken)
                    .when()
                    .delete("/records/share-codes/" + shareCode1)
                    .then()
                    .statusCode(anyOf(equalTo(404), equalTo(410)));
        }

        @Test
        @DisplayName("Non-patient users should not be able to list share codes")
        public void shouldRejectNonPatientListingCodes() {
            Assumptions.assumeTrue(doctorIdToken != null, "Doctor not logged in");

            given()
                    .header("x-api-key", config.getApiKey())
                    .header("Authorization", "Bearer " + doctorIdToken)
                    .when()
                    .get("/records/share-codes")
                    .then()
                    .statusCode(anyOf(equalTo(403), equalTo(200)))
                    .body(anyOf(
                            hasEntry("message", notNullValue()),
                            hasEntry("shareCodes", emptyIterable())
                    ));
        }

        @Test
        @DisplayName("Should reject revocation without authentication")
        public void shouldRejectUnauthenticatedRevocation() {
            given()
                    .header("x-api-key", config.getApiKey())
                    .when()
                    .delete("/records/share-codes/ABC123")
                    .then()
                    .statusCode(401);
        }
    }
}
