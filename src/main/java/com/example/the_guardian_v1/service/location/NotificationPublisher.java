package com.example.the_guardian_v1.service.location;

import com.example.the_guardian_v1.dto.location.GeofenceAlertMessage;
import com.example.the_guardian_v1.dto.location.NotificationMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

/**
 * Pushes alerts to the parent's dedicated WebSocket topic.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationPublisher {

    private static final String TOPIC_PREFIX = "/topic/alerts/";

    private final SimpMessagingTemplate messagingTemplate;

    public void pushGeofenceAlert(GeofenceAlertMessage alert) {
        String destination = TOPIC_PREFIX + alert.getParentId();
        log.info("WS geofence alert → {} | child={} fence={} transition={}",
                destination, alert.getChildId(), alert.getGeofenceName(), alert.getTransition());
        messagingTemplate.convertAndSend(destination, alert);
    }

    public void pushNotification(NotificationMessage notification) {
        String destination = TOPIC_PREFIX + notification.getParentId();
        log.info("WS notification → {} | type={} child={} message={}",
                destination, notification.getType(), notification.getChildId(), notification.getMessage());
        messagingTemplate.convertAndSend(destination, notification);
    }
}
