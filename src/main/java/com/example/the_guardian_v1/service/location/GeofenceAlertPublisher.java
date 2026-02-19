package com.example.the_guardian_v1.service.location;

import com.example.the_guardian_v1.dto.location.GeofenceAlertMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

/**
 * Pushes geofence alerts to the parent's dedicated WebSocket topic.
 *
 * Topic pattern: /topic/alerts/{parentId}
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class GeofenceAlertPublisher {

    private static final String TOPIC_PREFIX = "/topic/alerts/";

    private final SimpMessagingTemplate messagingTemplate;

    public void pushAlert(GeofenceAlertMessage alert) {
        String destination = TOPIC_PREFIX + alert.getParentId();
        log.info("WS alert → {} | child={} fence={} transition={}",
                destination, alert.getChildId(), alert.getGeofenceName(), alert.getTransition());
        messagingTemplate.convertAndSend(destination, alert);
    }
}
