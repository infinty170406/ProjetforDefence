package com.example.the_guardian_v1.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.beans.factory.annotation.Value;
import java.util.List;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import java.util.Collections;
import org.springframework.security.config.Customizer;

@Configuration
public class SecurityConfig {

  private final SupabaseUserSyncFilter supabaseUserSyncFilter;
  private final ExecuteApiKeyFilter executeApiKeyFilter;

  @Value("${app.cors.allowed-origins}")
  private String allowedOrigins;

  public SecurityConfig(SupabaseUserSyncFilter supabaseUserSyncFilter, ExecuteApiKeyFilter executeApiKeyFilter) {
    this.supabaseUserSyncFilter = supabaseUserSyncFilter;
    this.executeApiKeyFilter = executeApiKeyFilter;
  }

  @Bean
  public UserDetailsService userDetailsService() {
    return new InMemoryUserDetailsManager(Collections.emptyList());
  }

  @Bean
  public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    http.csrf(csrf -> csrf.disable())
        .cors(Customizer.withDefaults())
        .headers(h -> h.frameOptions(f -> f.disable()))
        .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/v1/auth/kyc/verify").authenticated()
            .requestMatchers("/api/v1/auth/**").permitAll()
            .requestMatchers("/api/v1/execute/**").permitAll()
            .requestMatchers("/api/v1/children/activate").permitAll()
            .requestMatchers("/h2-console/**").permitAll()
            .requestMatchers("/swagger-ui/**", "/v3/api-docs/**", "/swagger-ui.html").permitAll()
            .requestMatchers("/actuator/**").permitAll()
            .anyRequest().authenticated())
        .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
        .addFilterBefore(executeApiKeyFilter, UsernamePasswordAuthenticationFilter.class)
        .addFilterAfter(supabaseUserSyncFilter, UsernamePasswordAuthenticationFilter.class);
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
