package com.example.the_guardian_v1.domain.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "parents", indexes = { @Index(name = "idx_parent_email", columnList = "email", unique = true) })
@Getter
@Setter

public class Parent extends Auditable {

  @Id
  @Column(length = 36)
  private String id;

  @Column(nullable = false, length = 320, unique = true)
  private String email;

  @Column(nullable = false, length = 100)
  private String passwordHash;

  @Column(nullable = false, length = 120)
  private String name;

  @Column(length = 20)
  private String phoneNumber;

  @Column(nullable = false, length = 20)
  private String status;

  @Column(length = 6)
  private String otpCode;

  @Column
  private java.time.LocalDateTime otpExpiresAt;

  @Column(nullable = false, columnDefinition = "boolean default false")
  private Boolean verified = false;

}
