package com.example.the_guardian_v1.security;

import com.example.the_guardian_v1.domain.model.Parent;
import com.example.the_guardian_v1.repository.ParentRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
@Slf4j
public class SupabaseUserSyncFilter extends OncePerRequestFilter {

    private final ParentRepository parentRepository;

    public SupabaseUserSyncFilter(ParentRepository parentRepository) {
        this.parentRepository = parentRepository;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

        if (authentication != null && authentication.getPrincipal() instanceof Jwt jwt) {
            String supabaseId = jwt.getSubject(); // 'sub' claim
            String email = jwt.getClaimAsString("email");

            if (supabaseId != null && parentRepository.findById(supabaseId).isEmpty()) {
                log.info("New Supabase user detected (ID: {}), creating local Parent profile", supabaseId);
                Parent parent = new Parent();
                parent.setId(supabaseId);
                parent.setEmail(email != null ? email : "unknown@supabase.io");
                parent.setName(email != null ? email.split("@")[0] : "Supabase User");
                parent.setStatus("ACTIVE");
                parent.setVerified(true);
                parent.setKycVerified(false);
                parentRepository.save(parent);
            }
        }

        filterChain.doFilter(request, response);
    }
}
