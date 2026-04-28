package com.aidoui.e2e;

import com.aidoui.e2e.config.TestConfig;
import io.restassured.RestAssured;
import io.restassured.config.HttpClientConfig;
import io.restassured.config.RestAssuredConfig;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import org.junit.jupiter.api.*;

import java.util.concurrent.TimeUnit;

import java.io.File;

import static io.restassured.RestAssured.*;
import static org.assertj.core.api.Assertions.*;
import static org.hamcrest.Matchers.*;

/**
 * E2E Test: Complete Patient-Doctor Workflow
 *
 * This test covers the entire flow from patient login through record sharing,
 * doctor redemption, record upload, and verification.
 *
 * Converted from: scripts/e2e/e2e_patient_doctor_flow.sh
 *
 * Test Flow:
 * 1. Patient logs in
 * 2. Patient generates share code with selective record types
 * 3. Verify provider cannot redeem their own code (self-access prevention)
 * 4. Doctor logs in
 * 5. Doctor redeems share code and gets pass token
 * 6. Doctor uploads lab result using pass token
 * 7. Patient verifies the uploaded record appears in their records
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@DisplayName("E2E: Patient-Doctor Flow")
@Timeout(value = 45, unit = TimeUnit.SECONDS)
public class PatientDoctorFlowTest {

    private TestConfig config;
    private String patientIdToken;
    private String doctorIdToken;
    private String shareCode;
    private String passToken;
    private String uploadedRecordId;

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
                .body("accessToken", notNullValue())
                .body("user.role", equalTo("Patient"))
                .extract().response();

        patientIdToken = response.path("idToken");
        assertThat(patientIdToken)
                .as("Patient ID token should be present")
                .isNotEmpty();
    }

    @Test
    @Order(2)
    @DisplayName("Step 2: Patient should generate share code with selective record types")
    public void step2_patientGeneratesShareCode() {
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
                .body("code", matchesPattern("[A-Z0-9]{6}"))
                .body("expiresAt", notNullValue())
                .extract().response();

        shareCode = response.path("code");
        assertThat(shareCode)
                .as("Share code should be 6 characters")
                .hasSize(6);

        // Log the allowed record types if present
        if (response.path("recordTypes") != null) {
            System.out.println("Allowed record types: " + response.path("recordTypes").toString());
        }
    }

    @Test
    @Order(3)
    @DisplayName("Step 3: Patient should NOT be able to redeem their own share code (self-access prevention)")
    public void step3_preventSelfRedemption() {
        given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "code": "%s"
                        }
                        """, shareCode))
                .when()
                .post("/records/issue-pass")
                .then()
                .statusCode(403)  // Forbidden
                .body("message", containsString("cannot access their own"));
    }

    @Test
    @Order(4)
    @DisplayName("Step 4: Doctor should log in successfully")
    public void step4_doctorLogin() {
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
        assertThat(doctorIdToken)
                .as("Doctor ID token should be present")
                .isNotEmpty();
    }

    @Test
    @Order(5)
    @DisplayName("Step 5: Doctor should redeem share code and receive pass token")
    public void step5_doctorRedeemsShareCode() {
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
                .body("patientId", notNullValue())
                .body("capabilities.canView", equalTo(true))
                .body("capabilities.canUpload", equalTo(true))
                .extract().response();

        passToken = response.path("passToken");
        assertThat(passToken)
                .as("Pass token should be present")
                .isNotEmpty();

        System.out.println("Pass token capabilities: " + response.path("capabilities").toString());
    }

    @Test
    @Order(6)
    @DisplayName("Step 6: Doctor should upload lab result using pass token")
    public void step6_doctorUploadsLabResult() {
        // Check if test fixture exists
        File testFile = new File("scripts/fixtures/TestLabResult.pdf");
        Assumptions.assumeTrue(testFile.exists(),
                "Test fixture TestLabResult.pdf not found - skipping upload test");

        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + passToken)
                .multiPart("file", testFile, "application/pdf")
                .multiPart("type", "LAB")
                .multiPart("notes", "E2E Test - Lab Result Upload")
                .multiPart("diagnosisCode", "R50.9")  // ICD-10 for fever
                .when()
                .post("/records")
                .then()
                .statusCode(200)
                .body("id", notNullValue())
                .extract().response();

        uploadedRecordId = response.path("id");
        assertThat(uploadedRecordId)
                .as("Uploaded record ID should be present")
                .isNotEmpty();

        System.out.println("Uploaded record ID: " + uploadedRecordId);
    }

    @Test
    @Order(7)
    @DisplayName("Step 7: Patient should see the uploaded record in their records")
    public void step7_patientVerifiesUploadedRecord() {
        Assumptions.assumeTrue(uploadedRecordId != null,
                "No record was uploaded - skipping verification");

        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .when()
                .get("/records")
                .then()
                .statusCode(200)
                .body("items", notNullValue())
                .body("items.size()", greaterThan(0))
                .extract().response();

        // Verify our uploaded record is in the list
        boolean recordFound = response.path("items.find { it.id == '" + uploadedRecordId + "' }") != null;
        assertThat(recordFound)
                .as("Uploaded record should appear in patient's records")
                .isTrue();

        // Verify record details
        given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .when()
                .get("/records")
                .then()
                .body("items.find { it.id == '" + uploadedRecordId + "' }.type", equalTo("LAB"))
                .body("items.find { it.id == '" + uploadedRecordId + "' }.notes", containsString("E2E Test"));
    }

    @Nested
    @DisplayName("Error Scenarios")
    class ErrorScenarios {

        @Test
        @DisplayName("Should reject invalid share code")
        public void shouldRejectInvalidShareCode() {
            given()
                    .header("x-api-key", config.getApiKey())
                    .header("Authorization", "Bearer " + doctorIdToken)
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                                "code": "INVALID"
                            }
                            """)
                    .when()
                    .post("/records/issue-pass")
                    .then()
                    .statusCode(404);
        }

        @Test
        @DisplayName("Should reject double redemption of same code")
        public void shouldRejectDoubleRedemption() {
            Assumptions.assumeTrue(shareCode != null, "Share code not available");

            // Try to redeem the same code again
            given()
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
                    .statusCode(409)  // Conflict
                    .body("message", containsString("already redeemed"));
        }
    }
}
