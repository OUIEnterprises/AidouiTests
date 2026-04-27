package com.aidoui.e2e.config;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

/**
 * Test configuration loader for environment-specific settings.
 * Loads configuration from test-{env}.properties files.
 */
public class TestConfig {
    private static final String DEFAULT_ENV = "beta";
    private final Properties properties;
    private final String environment;

    private static TestConfig instance;

    private TestConfig() {
        this.environment = System.getProperty("env", DEFAULT_ENV);
        this.properties = loadProperties();
    }

    public static synchronized TestConfig getInstance() {
        if (instance == null) {
            instance = new TestConfig();
        }
        return instance;
    }

    private Properties loadProperties() {
        Properties props = new Properties();
        String configFile = String.format("test-%s.properties", environment);

        try (InputStream input = getClass().getClassLoader().getResourceAsStream(configFile)) {
            if (input == null) {
                throw new RuntimeException("Unable to find " + configFile);
            }
            props.load(input);
        } catch (IOException ex) {
            throw new RuntimeException("Failed to load configuration", ex);
        }

        return props;
    }

    public String getApiUrl() {
        return properties.getProperty("api.url");
    }

    public String getApiKey() {
        return properties.getProperty("api.key");
    }

    public String getPatientEmail() {
        return properties.getProperty("test.patient.email");
    }

    public String getPatientPassword() {
        return properties.getProperty("test.patient.password");
    }

    public String getDoctorEmail() {
        return properties.getProperty("test.doctor.email");
    }

    public String getDoctorPassword() {
        return properties.getProperty("test.doctor.password");
    }

    public String getEnvironment() {
        return environment;
    }

    public int getRequestTimeout() {
        return Integer.parseInt(properties.getProperty("api.timeout", "30000"));
    }

    /**
     * Get a property value by key.
     * Useful for accessing dynamic or test-specific properties.
     *
     * @param key Property key
     * @return Property value, or null if not found
     */
    public String getProperty(String key) {
        return properties.getProperty(key);
    }

    /**
     * Get a property value with a default fallback.
     *
     * @param key Property key
     * @param defaultValue Default value if property not found
     * @return Property value, or defaultValue if not found
     */
    public String getProperty(String key, String defaultValue) {
        return properties.getProperty(key, defaultValue);
    }
}
