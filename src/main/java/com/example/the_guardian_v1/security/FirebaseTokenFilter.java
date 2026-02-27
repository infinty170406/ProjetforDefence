package com.example.the_guardian_v1.security;

import com.example.the_guardian_v1.domain.model.Parent;
import com.example.the_guardian_v1.repository.ParentRepository;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseToken;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * Replaces SupabaseUserSyncFilter.
 * <p>
 * For every request carrying an
 * {@code Authorization: Bearer <Firebase ID Token>} header:
 * <ol>
 * <li>Verifies the token with Firebase Admin SDK (checks signature, expiry,
 * audience).</li>
 * <li>Extracts the Firebase UID and email from the decoded token.</li>
 * <li>Auto-creates a {@link Parent} row in the DB if this is the first request
 * from that UID.</li>
 * <li>Populates the Spring {@link SecurityContextHolder} so downstream code can
 * call
 * {@code authentication.getName()} to get the Firebase UID.</li>
 * </ol>
 */
@Component
@Slf4j
public class FirebaseTokenFilter extends OncePerRequestFilter {

    private final ParentRepository parentRepository;

    public FirebaseTokenFilter(ParentRepository parentRepository) {
        this.parentRepository = parentRepository;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain)
            throws ServletException, IOException {

        String authHeader = request.getHeader("Authorization");

        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String idToken = authHeader.substring(7);
            try {
                FirebaseToken decoded = FirebaseAuth.getInstance().verifyIdToken(idToken);
                String uid = decoded.getUid();
                String email = decoded.getEmail();

                // Auto-create Parent profile on first authenticated request
                if (!parentRepository.existsById(uid)) {
                    log.info("New Firebase user (UID={}), creating local Parent profile", uid);
                    Parent parent = new Parent();
                    parent.setId(uid);
                    parent.setEmail(email != null ? email : uid + "@firebase.local");
                    parent.setName(email != null ? email.split("@")[0] : "Firebase User");
                    parent.setStatus("ACTIVE");
                    parent.setVerified(true); // Firebase already verified the token
                    parent.setKycVerified(false);
                    parentRepository.save(parent);
                }

                // Set authenticated principal so @AuthenticationPrincipal / SecurityContext
                // work
                UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                        uid,
                        null,
                        List.of(new SimpleGrantedAuthority("ROLE_USER")));
                SecurityContextHolder.getContext().setAuthentication(authentication);

            } catch (FirebaseAuthException e) {
                log.warn("Firebase token verification failed: {}", e.getMessage());
                // Don't set authentication — Spring Security will reject protected routes
            } catch (IllegalStateException e) {
                log.warn("FirebaseApp not initialized (missing credentials?): {}", e.getMessage());
            }
        }

        filterChain.doFilter(request, response);
    }
}
