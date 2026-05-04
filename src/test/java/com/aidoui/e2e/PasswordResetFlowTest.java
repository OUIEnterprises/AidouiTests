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
import static org.hamcrest.Matchers.*;
import static org.hamcrest.MatcherAssert.assertThat;

/**
 * E2E Test: Password Reset Flow
 *
 * This test covers the complete password reset workflow including:
 * - Requesting a password reset code via email
 * - Confirming password reset with verification code
 * - Verifying login with new password
 *
 * Test Flow:
 * 1. Request password reset for patient account
 * 2. Verify reset code request is successful
 * 3. Confirm password reset with code (mocked verification code)
 * 4. Login with new password to verify reset worked
 * 5. Reset password back to original for test cleanup
 *
 * DISABLED: Requires SES email configuration to receive verification codes.
 * See AidouiCDK/docs/SES_EMAIL_SETUP.md for setup instructions.
 * Re-enable this test after SES is configured in beta environment.
 *
 * NOTE: This test uses mocked verification codes in test environments.
 * In production, codes are sent via email (AWS SES/SNS).
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@Disabled("Requires SES email configuration - see AidouiCDK/docs/SES_EMAIL_SETUP.md")
@DisplayName("E2E: Password Reset Flow")
@Timeout(value = 45, unit = TimeUnit.SECONDS)
public class PasswordResetFlowTest {

    private TestConfig config;
    private String patientEmail;
    private String originalPassword;
    private String newPassword = "NewTestPassword123!";
    private String verificationCode;

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

        patientEmail = config.getPatientEmail();
        originalPassword = config.getPatientPassword();
    }

    @Test
    @Order(1)
    @DisplayName("Step 1: Request password reset - should send verification code")
    public void step1_requestPasswordReset() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "email": "%s"
                        }
                        """, patientEmail))
                .when()
                .post("/auth/forgot-password")
                .then()
                .statusCode(200)
                .body("message", notNullValue())
                .body("message", containsStringIgnoringCase("verification code"))
                .extract().response();

        String message = response.path("message");
        System.out.println("Reset request response: " + message);

        assertThat("Response message should confirm code was sent", message, is(not(emptyString())));
    }

    @Test
    @Order(2)
    @DisplayName("Step 2: Confirm password reset with invalid code - should fail")
    public void step2_confirmWithInvalidCode() {
        given()
                .header("x-api-key", config.getApiKey())
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "email": "%s",
                            "code": "000000",
                            "newPassword": "%s"
                        }
                        """, patientEmail, newPassword))
                .when()
                .post("/auth/confirm-forgot-password")
                .then()
                .statusCode(anyOf(equalTo(400), equalTo(403)))
                .body("message", notNullValue());
    }

    @Test
    @Order(3)
    @DisplayName("Step 3: Confirm password reset with valid code - should succeed")
    public void step3_confirmPasswordReset() {
        // For test environments, we use a known verification code from AWS Cognito test config
        // In production, this would come from the user's email
        verificationCode = config.getProperty("test.verification.code", "123456");

        Response response = given()
                .header("x-api-key", config.getApiKey())
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "email": "%s",
                            "code": "%s",
                            "newPassword": "%s"
                        }
                        """, patientEmail, verificationCode, newPassword))
                .when()
                .post("/auth/confirm-forgot-password")
                .then()
                .statusCode(200)
                .body("message", notNullValue())
                .body("message", containsStringIgnoringCase("password"))
                .extract().response();

        String message = response.path("message");
        System.out.println("Password reset confirmed: " + message);
    }

    @Test
    @Order(4)
    @DisplayName("Step 4: Login with old password - should fail")
    public void step4_loginWithOldPasswordFails() {
        given()
                .header("x-api-key", config.getApiKey())
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "email": "%s",
                            "password": "%s"
                        }
                        """, patientEmail, originalPassword))
                .when()
                .post("/login")
                .then()
                .statusCode(anyOf(equalTo(401), equalTo(403)));
    }

    @Test
    @Order(5)
    @DisplayName("Step 5: Login with new password - should succeed")
    public void step5_loginWithNewPassword() {
        Response response = given()
                .header("x-api-key", config.getApiKey())
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "email": "%s",
                            "password": "%s"
                        }
                        """, patientEmail, newPassword))
                .when()
                .post("/login")
                .then()
                .statusCode(200)
                .body("idToken", notNullValue())
                .body("accessToken", notNullValue())
                .body("user.email", equalTo(patientEmail))
                .extract().response();

        String idToken = response.path("idToken");
        assertThat("ID token should be present after login with new password", idToken, is(not(emptyString())));

        System.out.println("Successfully logged in with new password");
    }

    @Test
    @Order(6)
    @DisplayName("Cleanup: Reset password back to original")
    public void step6_resetPasswordBackToOriginal() {
        // Request another password reset
        given()
                .header("x-api-key", config.getApiKey())
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "email": "%s"
                        }
                        """, patientEmail))
                .when()
                .post("/auth/forgot-password")
                .then()
                .statusCode(200);

        // Confirm with original password
        verificationCode = config.getProperty("test.verification.code", "123456");

        given()
                .header("x-api-key", config.getApiKey())
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "email": "%s",
                            "code": "%s",
                            "newPassword": "%s"
                        }
                        """, patientEmail, verificationCode, originalPassword))
                .when()
                .post("/auth/confirm-forgot-password")
                .then()
                .statusCode(200);

        // Verify original password works
        given()
                .header("x-api-key", config.getApiKey())
                .contentType(ContentType.JSON)
                .body(String.format("""
                        {
                            "email": "%s",
                            "password": "%s"
                        }
                        """, patientEmail, originalPassword))
                .when()
                .post("/login")
                .then()
                .statusCode(200)
                .body("idToken", notNullValue());

        System.out.println("Password reset back to original for future tests");
    }

    @Nested
    @DisplayName("Error Scenarios")
    class ErrorScenarios {

        @Test
        @DisplayName("Should reject password reset for non-existent email")
        public void shouldRejectNonExistentEmail() {
            given()
                    .header("x-api-key", config.getApiKey())
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                                "email": "nonexistent@example.com"
                            }
                            """)
                    .when()
                    .post("/auth/forgot-password")
                    .then()
                    .statusCode(anyOf(equalTo(200), equalTo(404)));
            // Note: For security, some systems return 200 even for non-existent emails
        }

        @Test
        @DisplayName("Should reject weak password in reset confirmation")
        public void shouldRejectWeakPassword() {
            given()
                    .header("x-api-key", config.getApiKey())
                    .contentType(ContentType.JSON)
                    .body(String.format("""
                            {
                                "email": "%s",
                                "code": "123456",
                                "newPassword": "weak"
                            }
                            """, patientEmail))
                    .when()
                    .post("/auth/confirm-forgot-password")
                    .then()
                    .statusCode(400)
                    .body("message", containsStringIgnoringCase("password"));
        }

        @Test
        @DisplayName("Should reject empty verification code")
        public void shouldRejectEmptyCode() {
            given()
                    .header("x-api-key", config.getApiKey())
                    .contentType(ContentType.JSON)
                    .body(String.format("""
                            {
                                "email": "%s",
                                "code": "",
                                "newPassword": "ValidPassword123!"
                            }
                            """, patientEmail))
                    .when()
                    .post("/auth/confirm-forgot-password")
                    .then()
                    .statusCode(400);
        }
    }
}
