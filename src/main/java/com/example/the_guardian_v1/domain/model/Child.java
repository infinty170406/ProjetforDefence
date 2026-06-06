package com.example.the_guardian_v1.domain.model;

import jakarta.persistence.*;
import java.time.Instant;
import lombok.*;

@Entity
@Table(name = "children", indexes = { @Index(name = "idx_child_parent", columnList = "parentId") })
@Getter
@Setter
public class Child extends Auditable {

  @Id
  @Column(length = 36)
  private String id;

  @Column(nullable = false, length = 36)
  private String parentId;

  @Column(nullable = false, length = 80)
  private String displayName;

  private Integer age;

  @Column(nullable = false, length = 20)
  private String status;

  private Instant lastSeenAt;

  @Column(length = 100)
  private String invitationToken;

  private Instant invitationExpiresAt;

}
