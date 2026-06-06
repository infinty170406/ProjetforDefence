package com.example.the_guardian_v1.security;

import jakarta.servlet.*;
import jakarta.servlet.http.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
public class ExecuteApiKeyFilter extends OncePerRequestFilter {

  private final String apiKey;

  public ExecuteApiKeyFilter(@Value("${the_guardian.execute.apiKey}") String apiKey) {
    this.apiKey = apiKey;
  }

  @Override
  protected boolean shouldNotFilter(HttpServletRequest request) {
    return !request.getRequestURI().startsWith("/api/v1/execute");
  }

  @Override
  protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
      throws ServletException, IOException {

    String key = request.getHeader("X-EXECUTE-KEY");
    if (key == null || key.isBlank() || !key.equals(apiKey)) {
      response.setStatus(HttpStatus.UNAUTHORIZED.value());
      response.getWriter().write("Missing/invalid X-EXECUTE-KEY");
      return;
    }
    chain.doFilter(request, response);
  }
}
