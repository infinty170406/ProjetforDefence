package com.example.the_guardian_v1.domain.model;

import com.example.the_guardian_v1.domain.enums.*;
import jakarta.persistence.*;
import lombok.*;
@Entity
@Table(name="content_rules", indexes = {@Index(name="idx_content_child_category", columnList="childId,category", unique=true)})
@Getter
@Setter
public class ContentRule extends Auditable {

  @Id @Column(length=36)
  private String id;

  @Column(nullable=false, length=36)
  private String childId;

  @Enumerated(EnumType.STRING)
  @Column(nullable=false, length=16)
  private ContentCategory category;

  @Enumerated(EnumType.STRING)
  @Column(nullable=false, length=10)
  private RuleAction action;

  private Double confidenceThreshold;

  @Column(nullable=false)
  private boolean enabled;

}
