package com.example.the_guardian_v1.domain.model;

import com.example.the_guardian_v1.domain.enums.*;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.*;

@Entity
@Table(name="enforcement_events", indexes = {@Index(name="idx_event_child_time", columnList="childId,occurredAt")})
@Getter @Setter
public class EnforcementEvent {

  @Id @Column(length=36)
  private String id;

  @Column(nullable=false, length=36)
  private String childId;

  @Enumerated(EnumType.STRING)
  @Column(nullable=false, length=30)
  private EventType type;

  @Enumerated(EnumType.STRING)
  @Column(nullable=false, length=10)
  private ActorType actor;

  @Column(nullable=false)
  private Instant occurredAt;

  @Lob
  @Column(nullable=false)
  private String payloadJson;

  @Column(nullable=false)
  private Instant createdAt;


}
