package com.example.the_guardian_v1.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
@Slf4j
public class DatabaseSchemaFix implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;

    public DatabaseSchemaFix(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void run(String... args) {
        log.info("Starting automated database schema check...");

        try {
            // Fix children table
            executeSilently("ALTER TABLE children ADD COLUMN IF NOT EXISTS invitation_token VARCHAR(100)");
            executeSilently("ALTER TABLE children ADD COLUMN IF NOT EXISTS invitation_expires_at TIMESTAMP");

            // Fix parents table
            executeSilently("ALTER TABLE parents ADD COLUMN IF NOT EXISTS verified BOOLEAN DEFAULT FALSE NOT NULL");
            executeSilently("ALTER TABLE parents ADD COLUMN IF NOT EXISTS otp_code VARCHAR(6)");
            executeSilently("ALTER TABLE parents ADD COLUMN IF NOT EXISTS otp_expires_at TIMESTAMP");

            log.info("Database schema check completed successfully.");
        } catch (Exception e) {
            log.error("Error during automated database schema fix: {}", e.getMessage());
        }
    }

    private void executeSilently(String sql) {
        try {
            jdbcTemplate.execute(sql);
            log.info("Executed SQL: {}", sql);
        } catch (Exception e) {
            // Ignorer si la colonne existe déjà (certaines versions de Postgres/H2 peuvent
            // varier sur 'IF NOT EXISTS')
            if (e.getMessage().contains("already exists")) {
                log.debug("Column already exists, skipping: {}", sql);
            } else {
                log.warn("SQL execution warning for '{}': {}", sql, e.getMessage());
            }
        }
    }
}
