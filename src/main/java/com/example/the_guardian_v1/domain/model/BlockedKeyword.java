package com.example.the_guardian_v1.domain.model;

import com.example.the_guardian_v1.domain.enums.*;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name="blocked_keywords", indexes = {
  @Index(name="idx_kw_child_category", columnList="childId,category"),
  @Index(name="idx_kw_term", columnList="term")
})
@Getter @Setter
public class BlockedKeyword extends Auditable {

  @Id @Column(length=36)
  private String id;

  @Column(nullable=false, length=36)
  private String childId;

  @Enumerated(EnumType.STRING)
  @Column(nullable=false, length=16)
  private ContentCategory category;

  @Column(nullable=false, length=120)
  private String term;

  @Column(nullable=false, length=12)
  private String locale;

  @Enumerated(EnumType.STRING)
  @Column(nullable=false, length=10)
  private KeywordMatchType matchType;

  @Column(nullable=false)
  private boolean enabled;

}
