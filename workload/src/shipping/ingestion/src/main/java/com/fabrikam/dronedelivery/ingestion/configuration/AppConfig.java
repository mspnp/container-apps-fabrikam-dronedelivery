package com.fabrikam.dronedelivery.ingestion.configuration;

import com.microsoft.applicationinsights.TelemetryClient;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AppConfig {

    @Bean
    public TelemetryClient telemetryClient() {
        return new TelemetryClient();
    }
}