package com.aidoui.e2e;

import com.aidoui.e2e.config.TestConfig;
import io.restassured.RestAssured;
import io.restassured.config.HttpClientConfig;
import io.restassured.config.RestAssuredConfig;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import org.junit.jupiter.api.*;

import java.util.concurrent.TimeUnit;

import static io.restassured.RestAssured.*;
import static org.assertj.core.api.Assertions.*;
import static org.hamcrest.Matchers.*;

/**
 * End-to-end tests for AIDOUI Records API endpoints.
 * Tests the complete workflow: Patient shares records -> Provider redeems code -> Provider accesses records.
 *
 * Based on: test/invoke/test-records-endpoints.sh
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@Timeout(value = 45, unit = TimeUnit.SECONDS) // Global timeout for all tests in this class
public class RecordsEndpointsTest {

    private TestConfig config;
    private String patientIdToken;
    private String doctorIdToken;
    private String shareCode;
    private String passToken;

    @BeforeAll
    public void setup() {
        config = TestConfig.getInstance();
        RestAssured.baseURI = config.getApiUrl();
        RestAssured.enableLoggingOfRequestAndResponseIfValidationFails();

        // Configure timeouts to prevent tests from hanging indefinitely
        int timeoutMs = config.getRequestTimeout(); // 30000ms from properties
        RestAssured.config = RestAssuredConfig.config()
            .httpClient(HttpClientConfig.httpClientConfig()
                .setParam("http.connection.timeout", timeoutMs)
                .setParam("http.socket.timeout", timeoutMs)
                .setParam("http.connection-manager.timeout", timeoutMs));
    }

    @Test
    @Order(1)
    @DisplayName("Patient should be able to login")
    public void testPatientLogin() {
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
                .body("refreshToken", notNullValue())
                .body("user.email", equalTo(config.getPatientEmail()))
                .body("user.role", equalTo("Patient"))
                .extract().response();

        patientIdToken = response.path("idToken");
        assertThat(patientIdToken).isNotEmpty();
    }

    @Test
    @Order(2)
    @DisplayName("Doctor should be able to login")
    public void testDoctorLogin() {
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
        assertThat(doctorIdToken).isNotEmpty();
    }

    @Test
    @Order(3)
    @DisplayName("Patient should be able to share records")
    public void testPatientShareRecords() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .contentType(ContentType.JSON)
                .body("""
                        {
                            "purpose": "DOCTOR_VISIT",
                            "ttlSeconds": 3600,
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
        assertThat(shareCode).hasSize(6);
    }

    @Test
    @Order(4)
    @DisplayName("Doctor should be able to redeem share code")
    public void testDoctorRedeemShareCode() {
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
        assertThat(passToken).isNotEmpty();
    }

    @Test
    @Order(5)
    @DisplayName("Doctor should be able to list active passes using Cognito JWT")
    public void testDoctorListActivePasses() {
        given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + doctorIdToken)
                .when()
                .get("/records/passes")
                .then()
                .statusCode(200)
                .body("passes", notNullValue())
                .body("passes.size()", greaterThan(0));
    }

    @Test
    @Order(6)
    @DisplayName("Doctor should be able to view patient records using pass token")
    public void testDoctorViewPatientRecords() {
        given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + passToken)
                .when()
                .get("/records")
                .then()
                .statusCode(200)
                .body("items", notNullValue())
                .body("items.size()", greaterThanOrEqualTo(0));
    }

    @Test
    @Order(7)
    @DisplayName("Patient should be able to view their own records using Cognito JWT")
    public void testPatientViewOwnRecords() {
        given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
                .when()
                .get("/records")
                .then()
                .statusCode(200)
                .body("items", notNullValue());
    }

    @Nested
    @DisplayName("Authorization Tests")
    class AuthorizationTests {

        @Test
        @DisplayName("Should reject request without API key")
        public void testMissingApiKey() {
            given()
                    .header("Authorization", "Bearer " + patientIdToken)
                    .when()
                    .get("/records")
                    .then()
                    .statusCode(403);
        }

        @Test
        @DisplayName("Should reject request with invalid token")
        public void testInvalidToken() {
            given()
                    .header("x-api-key", config.getApiKey())
                    .header("Authorization", "Bearer invalid-token")
                    .when()
                    .get("/records")
                    .then()
                    .statusCode(401);
        }

        @Test
        @DisplayName("Should reject POST /records with Cognito JWT (requires pass token)")
        public void testRecordsUploadRequiresPassToken() {
            given()
                    .header("x-api-key", config.getApiKey())
                    .header("Authorization", "Bearer " + doctorIdToken)
                    .contentType(ContentType.JSON)
                    .when()
                    .post("/records")
                    .then()
                    .statusCode(anyOf(is(401), is(403)));
        }
    }
}
