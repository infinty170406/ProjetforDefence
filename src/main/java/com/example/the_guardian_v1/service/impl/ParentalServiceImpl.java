package com.example.the_guardian_v1.service.impl;

import com.example.the_guardian_v1.common.exception.*;
import com.example.the_guardian_v1.domain.enums.*;
import com.example.the_guardian_v1.domain.model.*;
import com.example.the_guardian_v1.dto.parental.*;
import com.example.the_guardian_v1.repository.*;
import com.example.the_guardian_v1.service.*;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.LocalTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class ParentalServiceImpl implements IParentalService {

  private final IAuthorizationService authorizationService;
  private final ParentalProfileRepository profileRepo;
  private final ScheduleRuleRepository scheduleRepo;
  private final ContentRuleRepository contentRepo;
  private final BlockedKeywordRepository keywordRepo;
  private final EnforcementEventRepository eventRepo;

  public ParentalServiceImpl(IAuthorizationService authorizationService,
      ParentalProfileRepository profileRepo,
      ScheduleRuleRepository scheduleRepo,
      ContentRuleRepository contentRepo,
      BlockedKeywordRepository keywordRepo,
      EnforcementEventRepository eventRepo) {
    this.authorizationService = authorizationService;
    this.profileRepo = profileRepo;
    this.scheduleRepo = scheduleRepo;
    this.contentRepo = contentRepo;
    this.keywordRepo = keywordRepo;
    this.eventRepo = eventRepo;
  }

  @Override
  public ProfileAggregateDto getProfileAggregate(String childId) {
    authorizationService.assertCurrentParentOwnsChild(childId);

    ParentalProfile profile = profileRepo.findByChildId(childId).orElseGet(() -> {
      ParentalProfile p = new ParentalProfile();
      p.setId(UUID.randomUUID().toString());
      p.setChildId(childId);
      p.setEnabled(true);
      p.setMode(ProfileMode.STRICT);
      p.setTimezone("Africa/Douala");
      return profileRepo.save(p);
    });

    ProfileAggregateDto agg = new ProfileAggregateDto();
    agg.childId = childId;
    agg.profile = MappingUtils.toDto(profile);
    agg.scheduleRules = scheduleRepo.findByChildId(childId).stream().map(MappingUtils::toDto)
        .collect(Collectors.toList());
    agg.contentRules = contentRepo.findByChildId(childId).stream().map(MappingUtils::toDto)
        .collect(Collectors.toList());
    // V1: return all keywords across categories by scanning all categories (simple)
    List<BlockedKeywordDto> kw = new ArrayList<>();
    for (ContentCategory cat : ContentCategory.values()) {
      keywordRepo.findByChildIdAndCategory(childId, cat).stream().map(MappingUtils::toDto).forEach(kw::add);
    }
    agg.blockedKeywords = kw;
    return agg;
  }

  @Override
  public ParentalProfileDto updateProfile(String childId, UpdateParentalProfileRequest req) {
    authorizationService.assertCurrentParentOwnsChild(childId);

    ProfileMode mode;
    try {
      mode = ProfileMode.valueOf(req.mode.trim().toUpperCase());
    } catch (Exception e) {
      throw new ValidationException("Invalid mode: " + req.mode);
    }

    ParentalProfile p = profileRepo.findByChildId(childId).orElseGet(() -> {
      ParentalProfile np = new ParentalProfile();
      np.setId(UUID.randomUUID().toString());
      np.setChildId(childId);
      np.setTimezone("Africa/Douala");
      return np;
    });

    p.setEnabled(Boolean.TRUE.equals(req.enabled));
    p.setMode(mode);
    if (req.timezone != null && !req.timezone.isBlank())
      p.setTimezone(req.timezone);

    p = profileRepo.save(p);
    recordEvent(childId, EventType.PROFILE_UPDATED, ActorType.PARENT, "{\"type\":\"PROFILE_UPDATED\"}");
    return MappingUtils.toDto(p);
  }

  @Override
  public ScheduleRuleDto createSchedule(String childId, CreateScheduleRuleRequest req) {
    authorizationService.assertCurrentParentOwnsChild(childId);

    LocalTime start = MappingUtils.parseTime(req.startTime);
    LocalTime end = MappingUtils.parseTime(req.endTime);
    if (!end.isAfter(start))
      throw new ValidationException("endTime must be after startTime");

    RuleAction action;
    try {
      action = RuleAction.valueOf(req.action.trim().toUpperCase());
    } catch (Exception e) {
      throw new ValidationException("Invalid action: " + req.action);
    }
    if (!(action == RuleAction.ALLOW || action == RuleAction.BLOCK))
      throw new ValidationException("Schedule action must be ALLOW or BLOCK");

    ScheduleRule r = new ScheduleRule();
    r.setId(UUID.randomUUID().toString());
    r.setChildId(childId);
    r.setDaysOfWeek(MappingUtils.joinDays(req.daysOfWeek));
    r.setStartTime(start);
    r.setEndTime(end);
    r.setAction(action);
    r.setEnabled(req.enabled == null ? true : req.enabled);

    r = scheduleRepo.save(r);
    recordEvent(childId, EventType.SCHEDULE_CREATED, ActorType.PARENT, "{\"scheduleId\":\"" + r.getId() + "\"}");
    return MappingUtils.toDto(r);
  }

  @Override
  public ScheduleRuleDto updateSchedule(String childId, String scheduleId, UpdateScheduleRuleRequest req) {
    authorizationService.assertCurrentParentOwnsChild(childId);
    ScheduleRule r = scheduleRepo.findById(scheduleId).orElseThrow(() -> new NotFoundException("Schedule not found"));
    if (!childId.equals(r.getChildId()))
      throw new NotFoundException("Schedule not found");

    LocalTime start = MappingUtils.parseTime(req.startTime);
    LocalTime end = MappingUtils.parseTime(req.endTime);
    if (!end.isAfter(start))
      throw new ValidationException("endTime must be after startTime");

    RuleAction action;
    try {
      action = RuleAction.valueOf(req.action.trim().toUpperCase());
    } catch (Exception e) {
      throw new ValidationException("Invalid action: " + req.action);
    }
    if (!(action == RuleAction.ALLOW || action == RuleAction.BLOCK))
      throw new ValidationException("Schedule action must be ALLOW or BLOCK");

    r.setDaysOfWeek(MappingUtils.joinDays(req.daysOfWeek));
    r.setStartTime(start);
    r.setEndTime(end);
    r.setAction(action);
    r.setEnabled(req.enabled == null ? true : req.enabled);

    r = scheduleRepo.save(r);
    recordEvent(childId, EventType.SCHEDULE_UPDATED, ActorType.PARENT, "{\"scheduleId\":\"" + r.getId() + "\"}");
    return MappingUtils.toDto(r);
  }

  @Override
  public void deleteSchedule(String childId, String scheduleId) {
    authorizationService.assertCurrentParentOwnsChild(childId);
    ScheduleRule r = scheduleRepo.findById(scheduleId).orElseThrow(() -> new NotFoundException("Schedule not found"));
    if (!childId.equals(r.getChildId()))
      throw new NotFoundException("Schedule not found");
    scheduleRepo.delete(r);
    recordEvent(childId, EventType.SCHEDULE_DELETED, ActorType.PARENT, "{\"scheduleId\":\"" + scheduleId + "\"}");
  }

  @Override
  public ContentRuleDto upsertContentRule(String childId, ContentCategory category, UpsertContentRuleRequest req) {
    authorizationService.assertCurrentParentOwnsChild(childId);

    RuleAction action;
    try {
      action = RuleAction.valueOf(req.action.trim().toUpperCase());
    } catch (Exception e) {
      throw new ValidationException("Invalid action: " + req.action);
    }

    if (req.confidenceThreshold != null && (req.confidenceThreshold < 0.0 || req.confidenceThreshold > 1.0)) {
      throw new ValidationException("confidenceThreshold must be between 0.0 and 1.0");
    }

    ContentRule r = contentRepo.findByChildIdAndCategory(childId, category).orElseGet(() -> {
      ContentRule nr = new ContentRule();
      nr.setId(UUID.randomUUID().toString());
      nr.setChildId(childId);
      nr.setCategory(category);
      return nr;
    });

    r.setAction(action);
    r.setConfidenceThreshold(req.confidenceThreshold);
    r.setEnabled(req.enabled == null ? true : req.enabled);

    r = contentRepo.save(r);
    recordEvent(childId, EventType.CONTENT_RULE_UPSERTED, ActorType.PARENT,
        "{\"category\":\"" + category.name() + "\"}");
    return MappingUtils.toDto(r);
  }

  @Override
  public void replaceBlockedKeywords(String childId, ContentCategory category, List<String> keywords, String locale,
      String matchType) {
    authorizationService.assertCurrentParentOwnsChild(childId);

    KeywordMatchType mt;
    try {
      mt = KeywordMatchType.valueOf((matchType == null ? "CONTAINS" : matchType.trim().toUpperCase()));
    } catch (Exception e) {
      throw new ValidationException("Invalid keywordMatch: " + matchType);
    }

    String loc = (locale == null || locale.isBlank()) ? "fr" : locale.trim().toLowerCase();

    keywordRepo.deleteByChildIdAndCategory(childId, category);

    if (keywords != null) {
      for (String k : keywords) {
        if (k == null)
          continue;
        String term = k.trim();
        if (term.isBlank())
          continue;

        BlockedKeyword bk = new BlockedKeyword();
        bk.setId(UUID.randomUUID().toString());
        bk.setChildId(childId);
        bk.setCategory(category);
        bk.setTerm(term);
        bk.setLocale(loc);
        bk.setMatchType(mt);
        bk.setEnabled(true);
        keywordRepo.save(bk);
      }
    }
    recordEvent(childId, EventType.KEYWORDS_REPLACED, ActorType.N8N, "{\"category\":\"" + category.name() + "\"}");
  }

  @Override
  public List<EnforcementEventDto> getChildHistory(String childId) {
    authorizationService.assertCurrentParentOwnsChild(childId);
    return eventRepo.findByChildIdOrderByOccurredAtDesc(childId)
        .stream()
        .map(MappingUtils::toDto)
        .collect(Collectors.toList());
  }

  private void recordEvent(String childId, EventType type, ActorType actor, String payloadJson) {
    EnforcementEvent e = new EnforcementEvent();
    e.setId(UUID.randomUUID().toString());
    e.setChildId(childId);
    e.setType(type);
    e.setActor(actor);
    e.setOccurredAt(Instant.now());
    e.setPayloadJson(payloadJson == null ? "{}" : payloadJson);
    e.setCreatedAt(Instant.now());
    eventRepo.save(e);
  }
}
