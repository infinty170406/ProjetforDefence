package com.example.the_guardian_v1.domain.model;

import com.example.the_guardian_v1.domain.enums.ProfileMode;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name="parental_profiles", indexes = {@Index(name="idx_profile_child", columnList="childId", unique=true)})
@Getter
@Setter
public class ParentalProfile extends Auditable {

  @Id @Column(length=36)
  private String id;

  @Column(nullable=false, length=36, unique=true)
  private String childId;

  @Column(nullable=false)
  private boolean enabled;

  @Enumerated(EnumType.STRING)
  @Column(nullable=false, length=16)
  private ProfileMode mode;

  @Column(nullable=false, length=60)
  private String timezone;

}
