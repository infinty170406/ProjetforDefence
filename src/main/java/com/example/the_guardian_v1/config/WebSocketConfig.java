package com.example.the_guardian_v1.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.*;

/**
 * STOMP-over-WebSocket broker configuration.
 *
 * Client connection endpoint : /ws
 * Subscription prefix : /topic
 * Parent alert topic : /topic/alerts/{parentId}
 * App destination prefix : /app (for future client → server messaging)
 */
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        // Enable the in-process broker for /topic destinations.
        registry.enableSimpleBroker("/topic");
        // Prefix for @MessageMapping methods.
        registry.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*") // tightened via CORS config per-env
                .withSockJS(); // SockJS fallback for non-WS clients
    }
}
