package com.fabrikam.dronedelivery.ingestion;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

import com.fabrikam.dronedelivery.ingestion.configuration.ApplicationProperties;
import io.swagger.v3.oas.models.annotations.OpenAPI30;


@SpringBootApplication
@EnableConfigurationProperties(ApplicationProperties.class)
@OpenAPI30
public class IngestionApplication {

	public static void main(String[] args) {
		SpringApplication.run(IngestionApplication.class, args);
	}

}
