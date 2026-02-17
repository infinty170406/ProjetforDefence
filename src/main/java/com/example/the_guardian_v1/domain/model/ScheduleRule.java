package com.example.the_guardian_v1.domain.model;

import com.example.the_guardian_v1.domain.enums.RuleAction;
import jakarta.persistence.*;
import java.time.LocalTime;
import lombok.*;

@Entity
@Table(name="schedule_rules", indexes = {@Index(name="idx_schedule_child", columnList="childId")})
@Getter @Setter
public class ScheduleRule extends Auditable {

  @Id @Column(length=36)
  private String id;

  @Column(nullable=false, length=36)
  private String childId;

  @Column(nullable=false, length=120)
  private String daysOfWeek;

  @Column(nullable=false)
  private LocalTime startTime;

  @Column(nullable=false)
  private LocalTime endTime;

  @Enumerated(EnumType.STRING)
  @Column(nullable=false, length=10)
  private RuleAction action;

  @Column(nullable=false)
  private boolean enabled;

}
