package com.example.the_guardian_v1.service.impl;

import com.example.the_guardian_v1.domain.model.*;
import com.example.the_guardian_v1.dto.parent.ChildSummaryDto;
import com.example.the_guardian_v1.dto.parental.*;

import java.time.Instant;
import java.time.LocalTime;
import java.util.*;
import java.util.stream.Collectors;

public class MappingUtils {
  public static String iso(Instant i) {
    return i == null ? null : i.toString();
  }

  public static ParentalProfileDto toDto(ParentalProfile p) {
    ParentalProfileDto d = new ParentalProfileDto();
    d.profileId = p.getId();
    d.childId = p.getChildId();
    d.enabled = p.isEnabled();
    d.mode = p.getMode() == null ? null : p.getMode().name();
    d.timezone = p.getTimezone();
    d.updatedAt = iso(p.updatedAt);
    return d;
  }

  public static ScheduleRuleDto toDto(ScheduleRule r) {
    ScheduleRuleDto d = new ScheduleRuleDto();
    d.scheduleId = r.getId();
    d.childId = r.getChildId();
    d.daysOfWeek = r.getDaysOfWeek() == null ? List.of()
        : Arrays.stream(r.getDaysOfWeek().split(","))
            .filter(s -> !s.isBlank()).map(String::trim).collect(Collectors.toList());
    d.startTime = r.getStartTime() == null ? null : r.getStartTime().toString();
    d.endTime = r.getEndTime() == null ? null : r.getEndTime().toString();
    d.action = r.getAction() == null ? null : r.getAction().name();
    d.enabled = r.isEnabled();
    d.updatedAt = iso(r.updatedAt);
    return d;
  }

  public static ContentRuleDto toDto(ContentRule r) {
    ContentRuleDto d = new ContentRuleDto();
    d.ruleId = r.getId();
    d.childId = r.getChildId();
    d.category = r.getCategory() == null ? null : r.getCategory().name();
    d.action = r.getAction() == null ? null : r.getAction().name();
    d.confidenceThreshold = r.getConfidenceThreshold();
    d.enabled = r.isEnabled();
    d.updatedAt = iso(r.updatedAt);
    return d;
  }

  public static BlockedKeywordDto toDto(BlockedKeyword k) {
    BlockedKeywordDto d = new BlockedKeywordDto();
    d.keywordId = k.getId();
    d.childId = k.getChildId();
    d.category = k.getCategory() == null ? null : k.getCategory().name();
    d.term = k.getTerm();
    d.locale = k.getLocale();
    d.matchType = k.getMatchType() == null ? null : k.getMatchType().name();
    d.enabled = k.isEnabled();
    d.updatedAt = iso(k.updatedAt);
    return d;
  }

  public static ChildSummaryDto toDto(Child c) {
    ChildSummaryDto d = new ChildSummaryDto();
    d.childId = c.getId();
    d.displayName = c.getDisplayName();
    d.age = c.getAge();
    d.deviceStatus = "UNKNOWN";
    d.lastSeenAt = iso(c.getLastSeenAt());
    return d;
  }

  public static EnforcementEventDto toDto(EnforcementEvent e) {
    EnforcementEventDto d = new EnforcementEventDto();
    d.setEventId(e.getId());
    d.setChildId(e.getChildId());
    d.setType(e.getType() == null ? null : e.getType().name());
    d.setActor(e.getActor() == null ? null : e.getActor().name());
    d.setOccurredAt(iso(e.getOccurredAt()));
    d.setPayloadJson(e.getPayloadJson());
    d.setCreatedAt(iso(e.getCreatedAt()));
    return d;
  }

  public static LocalTime parseTime(String hhmm) {
    return LocalTime.parse(hhmm);
  }

  public static String joinDays(List<String> days) {
    return String.join(",", days);
  }
}
