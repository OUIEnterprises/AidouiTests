package com.aidoui.e2e;

import com.aidoui.e2e.config.TestConfig;
import io.restassured.RestAssured;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import org.junit.jupiter.api.*;

import static io.restassured.RestAssured.given;
import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.*;

/**
 * E2E Tests for Emergency Portal Access Control
 * 
 * Tests the Emergency integration including:
 * - Token passthrough SSO flow
 * - Access control (providers allowed, patients blocked)
 * - Emergency-specific record access
 * - Role-based permissions
 * 
 * Test Flow:
 * 1. Patient logs in and generates Emergency share code
 * 2. Emergency provider logs in via SSO
 * 3. Emergency provider redeems code and accesses records
 * 4. Patient attempt to access Emergency fails (403)
 * 5. Emergency provider can upload critical records
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@DisplayName("E2E: Emergency Portal Access Control")
public class EmergencyAccessTest {
    
    private TestConfig config;
    private String patientIdToken;
    private String doctorIdToken;
    private String hospitalIdToken;
    private String emergencyShareCode;
    private String emergencyPassToken;
    
    @BeforeAll
    public void setup() {
        config = TestConfig.getInstance();
        RestAssured.baseURI = config.getApiUrl();
        RestAssured.enableLoggingOfRequestAndResponseIfValidationFails();
    }
    
    // ============================================================================
    // PHASE 1: AUTHENTICATION
    // ============================================================================
    
    @Test
    @Order(1)
    @DisplayName("Patient should login successfully")
    public void patientLogin() {
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
            .body("user.email", equalTo(config.getPatientEmail()))
            .extract().response();
        
        patientIdToken = response.path("idToken");
        assertThat(patientIdToken).isNotEmpty();
    }
    
    @Test
    @Order(2)
    @DisplayName("Doctor should login successfully")
    public void doctorLogin() {
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
            .body("user.email", equalTo(config.getDoctorEmail()))
            .extract().response();
        
        doctorIdToken = response.path("idToken");
        assertThat(doctorIdToken).isNotEmpty();
    }
    
    @Test
    @Order(3)
    @DisplayName("Hospital should login successfully")
    public void hospitalLogin() {
        Response response = given()
            .header("x-api-key", config.getApiKey())
            .contentType(ContentType.JSON)
            .body(String.format("""
                {
                    "email": "%s",
                    "password": "%s"
                }
                """, config.getProperty("test.hospital.email"), config.getProperty("test.hospital.password")))
        .when()
            .post("/login")
        .then()
            .statusCode(200)
            .body("idToken", notNullValue())
            .body("user.role", equalTo("Hospital"))
            .extract().response();
        
        hospitalIdToken = response.path("idToken");
        assertThat(hospitalIdToken).isNotEmpty();
    }
    
    // ============================================================================
    // PHASE 2: EMERGENCY SHARE CODE GENERATION
    // ============================================================================
    
    @Test
    @Order(4)
    @DisplayName("Patient should generate Emergency share code")
    public void patientGeneratesEmergencyShareCode() {
        Assumptions.assumeTrue(patientIdToken != null, "Patient token not available");
        
        Response response = given()
            .header("x-api-key", config.getApiKey())
            .header("Authorization", "Bearer " + patientIdToken)
            .contentType(ContentType.JSON)
            .body("""
                {
                    "recordTypes": ["ALL"],
                    "accessType": "EMERGENCY",
                    "expiresInDays": 30
                }
                """)
        .when()
            .post("/records/share")
        .then()
            .statusCode(200)
            .body("code", notNullValue())
            .body("code", matchesPattern("[A-Z0-9]{6}"))
            .body("accessType", equalTo("EMERGENCY"))
            .body("expiresAt", notNullValue())
            .extract().response();
        
        emergencyShareCode = response.path("code");
        assertThat(emergencyShareCode)
            .isNotEmpty()
            .hasSize(6)
            .matches("[A-Z0-9]{6}");
    }
    
    // ============================================================================
    // PHASE 3: EMERGENCY ACCESS (Doctor as Emergency Provider)
    // ============================================================================
    
    @Test
    @Order(5)
    @DisplayName("Doctor should redeem Emergency share code")
    public void doctorRedeemsEmergencyCode() {
        Assumptions.assumeTrue(doctorIdToken != null, "Doctor token not available");
        Assumptions.assumeTrue(emergencyShareCode != null, "Emergency share code not available");
        
        Response response = given()
            .header("x-api-key", config.getApiKey())
            .header("Authorization", "Bearer " + doctorIdToken)
            .contentType(ContentType.JSON)
            .body(String.format("""
                {
                    "code": "%s"
                }
                """, emergencyShareCode))
        .when()
            .post("/records/issue-pass")
        .then()
            .statusCode(200)
            .body("passToken", notNullValue())
            .body("accessType", equalTo("EMERGENCY"))
            .body("recordTypes", hasItem("ALL"))
            .extract().response();
        
        emergencyPassToken = response.path("passToken");
        assertThat(emergencyPassToken).isNotEmpty();
    }
    
    @Test
    @Order(6)
    @DisplayName("Doctor should view patient records with Emergency pass")
    public void doctorViewsPatientRecordsWithEmergencyPass() {
        Assumptions.assumeTrue(emergencyPassToken != null, "Emergency pass token not available");
        
        given()
            .header("x-api-key", config.getApiKey())
            .header("Authorization", "Bearer " + emergencyPassToken)
        .when()
            .get("/records")
        .then()
            .statusCode(200)
            .body("items", notNullValue())
            .body("items.size()", greaterThanOrEqualTo(0))
            .body("accessType", equalTo("EMERGENCY"));
    }
    
    @Test
    @Order(7)
    @DisplayName("Hospital should redeem Emergency share code")
    public void hospitalRedeemsEmergencyCode() {
        Assumptions.assumeTrue(hospitalIdToken != null, "Hospital token not available");
        Assumptions.assumeTrue(emergencyShareCode != null, "Emergency share code not available");
        
        // Hospital can also redeem Emergency codes (emergency providers)
        given()
            .header("x-api-key", config.getApiKey())
            .header("Authorization", "Bearer " + hospitalIdToken)
            .contentType(ContentType.JSON)
            .body(String.format("""
                {
                    "code": "%s"
                }
                """, emergencyShareCode))
        .when()
            .post("/records/issue-pass")
        .then()
            .statusCode(200)
            .body("passToken", notNullValue())
            .body("accessType", equalTo("EMERGENCY"));
    }
    
    // ============================================================================
    // PHASE 4: ACCESS CONTROL & SECURITY
    // ============================================================================
    
    @Nested
    @DisplayName("Emergency Access Control")
    class EmergencyAccessControl {
        
        @Test
        @DisplayName("Patient cannot access Emergency records directly")
        public void patientCannotAccessEmergencyRecords() {
            Assumptions.assumeTrue(patientIdToken != null, "Patient token not available");
            
            given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + patientIdToken)
            .when()
                .get("/emergency/records")
            .then()
                .statusCode(anyOf(is(403), is(404)));  // Forbidden or Not Found
        }
        
        @Test
        @DisplayName("Invalid Emergency code should be rejected")
        public void invalidEmergencyCodeRejected() {
            Assumptions.assumeTrue(doctorIdToken != null, "Doctor token not available");
            
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
                .statusCode(404)
                .body("message", containsString("not found"));
        }
        
        @Test
        @DisplayName("Emergency pass token should not work for non-emergency endpoints")
        public void emergencyPassLimitedScope() {
            Assumptions.assumeTrue(emergencyPassToken != null, "Emergency pass token not available");
            
            // Emergency pass should not allow sharing new records
            given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer " + emergencyPassToken)
                .contentType(ContentType.JSON)
                .body("""
                    {
                        "recordTypes": ["ALL"],
                        "expiresInDays": 7
                    }
                    """)
            .when()
                .post("/records/share")
            .then()
                .statusCode(anyOf(is(401), is(403)));  // Unauthorized or Forbidden
        }
    }
    
    @Nested
    @DisplayName("Authorization Tests")
    class AuthorizationTests {
        
        @Test
        @DisplayName("Emergency endpoint should reject missing API key")
        public void shouldRejectMissingApiKey() {
            given()
                .header("Authorization", "Bearer " + (doctorIdToken != null ? doctorIdToken : "dummy-token"))
                .contentType(ContentType.JSON)
                .body("{\"code\": \"ABC123\"}")
            .when()
                .post("/records/issue-pass")
            .then()
                .statusCode(403)
                .body("message", containsString("Forbidden"));
        }
        
        @Test
        @DisplayName("Emergency endpoint should reject invalid token")
        public void shouldRejectInvalidToken() {
            given()
                .header("x-api-key", config.getApiKey())
                .header("Authorization", "Bearer invalid-token")
                .contentType(ContentType.JSON)
                .body("{\"code\": \"ABC123\"}")
            .when()
                .post("/records/issue-pass")
            .then()
                .statusCode(401)
                .body("message", containsString("Unauthorized"));
        }
    }
    
    // ============================================================================
    // PHASE 5: EMERGENCY RECORD UPLOAD
    // ============================================================================
    
    @Test
    @Order(8)
    @DisplayName("Doctor should upload emergency record with Emergency pass")
    public void doctorUploadsEmergencyRecord() {
        Assumptions.assumeTrue(emergencyPassToken != null, "Emergency pass token not available");
        
        Response response = given()
            .header("x-api-key", config.getApiKey())
            .header("Authorization", "Bearer " + emergencyPassToken)
            .contentType(ContentType.JSON)
            .body("""
                {
                    "type": "EMERGENCY_RECORD",
                    "title": "Emergency Room Visit",
                    "description": "Patient admitted to ER with chest pain",
                    "priority": "HIGH",
                    "metadata": {
                        "facility": "City Hospital ER",
                        "admissionTime": "2026-04-27T10:30:00Z"
                    }
                }
                """)
        .when()
            .post("/records")
        .then()
            .statusCode(anyOf(is(200), is(201)))
            .body("type", equalTo("EMERGENCY_RECORD"))
            .body("title", equalTo("Emergency Room Visit"))
            .body("priority", equalTo("HIGH"))
            .extract().response();
        
        String recordId = response.path("id");
        assertThat(recordId).isNotEmpty();
    }
    
    @Test
    @Order(9)
    @DisplayName("Patient should see emergency record in their records")
    public void patientSeesEmergencyRecord() {
        Assumptions.assumeTrue(patientIdToken != null, "Patient token not available");
        
        given()
            .header("x-api-key", config.getApiKey())
            .header("Authorization", "Bearer " + patientIdToken)
        .when()
            .get("/records")
        .then()
            .statusCode(200)
            .body("items", notNullValue())
            .body("items.findAll { it.type == 'EMERGENCY_RECORD' }.size()", greaterThanOrEqualTo(1));
    }
}
