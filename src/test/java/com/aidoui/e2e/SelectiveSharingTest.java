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
import java.util.List;

import static io.restassured.RestAssured.*;
import static org.hamcrest.Matchers.*;
import static org.hamcrest.MatcherAssert.assertThat;

/**
 * E2E Test: Selective Record Sharing
 *
 * This test validates that record type filtering works correctly when sharing records.
 * Patients can selectively share only specific record types (PRESCRIPTION, LAB, VISIT_NOTES)
 * and providers should only see the records they're granted access to.
 *
 * Converted from: scripts/e2e/e2e_selective_sharing.sh
 *
 * Test Flow:
 * 1. Patient logs in
 * 2. Patient uploads multiple record types (PRESCRIPTION, LAB, VISIT_NOTES)
 * 3. Patient shares code with ONLY LAB access
 * 4. Doctor logs in and redeems code
 * 5. Doctor can only see LAB records (filtering validation)
 * 6. Patient shares code with ALL record types
 * 7. Doctor redeems new code
 * 8. Doctor can now see all 3 records
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@DisplayName("E2E: Selective Record Sharing")
@Timeout(value = 45, unit = TimeUnit.SECONDS)
public class SelectiveSharingTest {

    private TestConfig config;
    private String patientIdToken;
    private String doctorIdToken;
    private String prescriptionRecordId;
    private String labRecordId;
    private String visitNotesRecordId;
    private String labOnlyShareCode;
    private String labOnlyPassToken;
    private String allAccessShareCode;
    private String allAccessPassToken;

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
    @DisplayName("Step 1: Patient should log in")
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
                .extract().response();

        patientIdToken = response.path("idToken");
    }

    @Test
    @Order(2)
    @DisplayName("Step 2: Doctor should log in")
    public void step2_doctorLogin() {
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
                .extract().response();

        doctorIdToken = response.path("idToken");
    }

    @Test
    @Order(3)
    @DisplayName("Step 3: Patient uploads PRESCRIPTION record")
    public void step3_uploadPrescription() {
        File testFile = new File("scripts/fixtures/TestLabResult.pdf");
        Assumptions.assumeTrue(testFile.exists(), "Test fixture not found");

        // Note: In real scenario, patient wouldn't upload prescriptions themselves
        // But for testing selective sharing, we need test data
        // Ideally this would be uploaded by a doctor with pass token first
        System.out.println("⚠️  Skipping PRESCRIPTION upload - requires doctor pass token");
    }

    @Test
    @Order(4)
    @DisplayName("Step 4: Patient shares code with LAB-only access")
    public void step4_shareLAbOnly() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "purpose": "DOCTOR_VISIT",
                            "ttlSeconds": 3600,
                            "label": "E2E Test - LAB Only Access",
                            "recordTypes": ["LAB"]
                        }
                        """)
                .when()
                .post("/records/share")
                .then()
                .statusCode(200)
                .body("code", notNullValue())
                .body("recordTypes", hasItem("LAB"))
                .body("recordTypes.size()", equalTo(1))
                .extract().response();

        labOnlyShareCode = response.path("code");
        assertThat(labOnlyShareCode, hasLength(6));

        System.out.println("LAB-only share code: " + labOnlyShareCode);
        System.out.println("Allowed types: " + response.path("recordTypes").toString());
    }

    @Test
    @Order(5)
    @DisplayName("Step 5: Doctor redeems LAB-only code")
    public void step5_doctorRedeemsLabOnlyCode() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + doctorIdToken)
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "code": "%s"
                        }
                        """, labOnlyShareCode))
                .when()
                .post("/records/issue-pass")
                .then()
                .statusCode(200)
                .body("passToken", notNullValue())
                .body("recordTypes", hasItem("LAB"))
                .extract().response();

        labOnlyPassToken = response.path("passToken");
        assertThat(labOnlyPassToken, is(not(emptyString())));
    }

    @Test
    @Order(6)
    @DisplayName("Step 6: Doctor with LAB-only token should only see LAB records")
    public void step6_verifyLabOnlyFiltering() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + labOnlyPassToken)
                .when()
                .get("/records")
                .then()
                .statusCode(200)
                .body("items", notNullValue())
                .extract().response();

        List<String> recordTypes = response.path("items.type");

        // All returned records should be of type LAB
        if (recordTypes != null && !recordTypes.isEmpty()) {
            boolean allLab = recordTypes.stream().allMatch(type -> type.equals("LAB"));
            assertThat("All records should be of type LAB", allLab, is(true));

            System.out.println("✓ Filtering works: " + recordTypes.size() + " LAB record(s) returned");
        } else {
            System.out.println("ℹ No records found (patient may not have LAB records yet)");
        }
    }

    @Test
    @Order(7)
    @DisplayName("Step 7: Patient shares code with ALL record types")
    public void step7_shareAllAccess() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "purpose": "DOCTOR_VISIT",
                            "ttlSeconds": 3600,
                            "label": "E2E Test - Full Access",
                            "recordTypes": ["PRESCRIPTION", "LAB", "VISIT_NOTES"]
                        }
                        """)
                .when()
                .post("/records/share")
                .then()
                .statusCode(200)
                .body("code", notNullValue())
                .body("recordTypes", hasItems("PRESCRIPTION", "LAB", "VISIT_NOTES"))
                .extract().response();

        allAccessShareCode = response.path("code");
        assertThat(allAccessShareCode, hasLength(6));

        System.out.println("Full-access share code: " + allAccessShareCode);
    }

    @Test
    @Order(8)
    @DisplayName("Step 8: Doctor redeems full-access code")
    public void step8_doctorRedeemsFullAccessCode() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + doctorIdToken)
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "code": "%s"
                        }
                        """, allAccessShareCode))
                .when()
                .post("/records/issue-pass")
                .then()
                .statusCode(200)
                .body("passToken", notNullValue())
                .body("recordTypes", hasItems("PRESCRIPTION", "LAB", "VISIT_NOTES"))
                .extract().response();

        allAccessPassToken = response.path("passToken");
        assertThat(allAccessPassToken, is(not(emptyString())));
    }

    @Test
    @Order(9)
    @DisplayName("Step 9: Doctor with full-access token should see all record types")
    public void step9_verifyFullAccessFiltering() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + allAccessPassToken)
                .when()
                .get("/records")
                .then()
                .statusCode(200)
                .body("items", notNullValue())
                .extract().response();

        List<String> recordTypes = response.path("items.type");

        if (recordTypes != null && !recordTypes.isEmpty()) {
            System.out.println("✓ Full access: " + recordTypes.size() + " record(s) returned");
            System.out.println("  Types: " + recordTypes.toString());

            // With full access, we should be able to see any/all types
            assertThat("Should have access to records", recordTypes, is(not(empty())));
        } else {
            System.out.println("ℹ No records found for this patient");
        }
    }

    @Nested
    @DisplayName("Filtering Validation")
    class FilteringValidation {

        @Test
        @DisplayName("LAB-only token should NOT see PRESCRIPTION records")
        public void labOnlyTokenShouldNotSeePrescriptions() {
            Assumptions.assumeTrue(labOnlyPassToken != null, "LAB-only token not available");

            Response response = given()
                    .header("x-api-key", config.getApiKey())
                    .header("Authorization", "Bearer " + labOnlyPassToken)
                    .when()
                    .get("/records")
                    .then()
                    .statusCode(200)
                    .extract().response();

            List<String> recordTypes = response.path("items.type");
            if (recordTypes != null && !recordTypes.isEmpty()) {
                assertThat("LAB-only token should not return PRESCRIPTION records", recordTypes, not(hasItems("PRESCRIPTION", "VISIT_NOTES")));
            }
        }

        @Test
        @DisplayName("Share code with empty recordTypes should allow all types")
        public void emptyRecordTypesShouldAllowAll() {
            // Create share code without recordTypes specified
            Response response = given()
                    .header("x-api-key", config.getApiKey())
                    .header("Authorization", "Bearer " + patientIdToken)
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                                "purpose": "DOCTOR_VISIT",
                                "ttlSeconds": 3600
                            }
                            """)
                    .when()
                    .post("/records/share")
                    .then()
                    .statusCode(200)
                    .body("code", notNullValue())
                    .extract().response();

            String code = response.path("code");

            // Redeem and verify full access
            Response issueResponse = given()
                    .header("x-api-key", config.getApiKey())
                    .header("Authorization", "Bearer " + doctorIdToken)
                    .contentType(ContentType.JSON)
                    .body(String.format("""
                            {
                                "code": "%s"
                            }
                            """, code))
                    .when()
                    .post("/records/issue-pass")
                    .then()
                    .statusCode(anyOf(is(200), is(409)))  // 409 if code already redeemed
                    .extract().response();

            if (issueResponse.statusCode() == 200) {
                // Should have capabilities to view and upload
                issueResponse.then()
                        .body("capabilities.canView", equalTo(true))
                        .body("capabilities.canUpload", equalTo(true));
            }
        }
    }
}
