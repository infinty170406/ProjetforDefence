package com.example.the_guardian_v1.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
public class SecurityConfig {

  private final FirebaseTokenFilter firebaseTokenFilter;
  private final ExecuteApiKeyFilter executeApiKeyFilter;

  @Value("${app.cors.allowed-origins}")
  private String allowedOrigins;

  public SecurityConfig(FirebaseTokenFilter firebaseTokenFilter,
      ExecuteApiKeyFilter executeApiKeyFilter) {
    this.firebaseTokenFilter = firebaseTokenFilter;
    this.executeApiKeyFilter = executeApiKeyFilter;
  }

  @Bean
  public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    http
        .csrf(csrf -> csrf.disable())
        .cors(Customizer.withDefaults())
        .headers(h -> h.frameOptions(f -> f.disable()))
        .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth
            // KYC requires valid Firebase token (authentication)
            .requestMatchers("/api/v1/auth/kyc/verify").authenticated()
            // OTP endpoints are public (client calls before full auth)
            .requestMatchers("/api/v1/auth/otp/**").permitAll()
            // All other /auth/** routes are public (handled by Firebase on client)
            .requestMatchers("/api/v1/auth/**").permitAll()
            // n8n execute webhook — protected by API key filter
            .requestMatchers("/api/v1/execute/**").permitAll()
            // Child activation link is public
            .requestMatchers("/api/v1/children/activate").permitAll()
            // Dev / docs / ops
            .requestMatchers("/h2-console/**").permitAll()
            .requestMatchers("/swagger-ui/**", "/v3/api-docs/**", "/swagger-ui.html").permitAll()
            .requestMatchers("/actuator/**").permitAll()
            // Everything else requires a valid Firebase ID token
            .anyRequest().authenticated())
        // Firebase token filter runs after execute key filter
        .addFilterBefore(executeApiKeyFilter, UsernamePasswordAuthenticationFilter.class)
        .addFilterAfter(firebaseTokenFilter, UsernamePasswordAuthenticationFilter.class);

    return http.build();
  }

  @Bean
  public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration configuration = new CorsConfiguration();
    configuration.setAllowedOriginPatterns(List.of(allowedOrigins.split(",")));
    configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"));
    configuration.setAllowedHeaders(List.of("*"));
    configuration.setAllowCredentials(true);
    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", configuration);
    return source;
  }
}
