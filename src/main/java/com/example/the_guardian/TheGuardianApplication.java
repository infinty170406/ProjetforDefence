package com.example.the_guardian;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication
@EnableAsync
public class TheGuardianApplication {

	public static void main(String[] args) {
		SpringApplication.run(TheGuardianApplication.class, args);
	}

}
