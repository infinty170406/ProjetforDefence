package com.example.the_guardian_v1.security;

import io.jsonwebtoken.*;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {
  private final JwtService jwtService;
  public JwtAuthFilter(JwtService jwtService){ this.jwtService = jwtService; }

  @Override
  protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
      throws ServletException, IOException {
    String auth = request.getHeader("Authorization");
    if (auth != null && auth.startsWith("Bearer ")) {
      String token = auth.substring(7);
      try {
        Jws<Claims> parsed = jwtService.parseAndValidate(token);
        String parentId = parsed.getBody().getSubject();
        if (parentId != null && SecurityContextHolder.getContext().getAuthentication() == null) {
          UsernamePasswordAuthenticationToken a = new UsernamePasswordAuthenticationToken(parentId, null, Collections.emptyList());
          a.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
          SecurityContextHolder.getContext().setAuthentication(a);
        }
      } catch (Exception ignored) {}
    }
    chain.doFilter(request, response);
  }
}
