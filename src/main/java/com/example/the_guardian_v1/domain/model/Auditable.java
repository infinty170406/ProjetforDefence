package com.example.the_guardian_v1.domain.model;

import jakarta.persistence.*;
import java.time.Instant;
import lombok.*;

@MappedSuperclass
@Getter @Setter
public abstract class Auditable {
  @Column(nullable = false)
  public Instant createdAt;

  @Column(nullable = false)
  public Instant updatedAt;

  @PrePersist
  public void prePersist() {
    Instant now = Instant.now();
    this.createdAt = now;
    this.updatedAt = now;
  }

  @PreUpdate
  public void preUpdate() {
    this.updatedAt = Instant.now();
  }
}
