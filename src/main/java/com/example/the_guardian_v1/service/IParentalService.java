package com.example.the_guardian_v1.service;

import com.example.the_guardian_v1.domain.enums.ContentCategory;
import com.example.the_guardian_v1.dto.parental.*;
import java.util.List;

public interface IParentalService {

  ProfileAggregateDto getProfileAggregate(String childId);

  ParentalProfileDto updateProfile(String childId, UpdateParentalProfileRequest req);

  ScheduleRuleDto createSchedule(String childId, CreateScheduleRuleRequest req);

  ScheduleRuleDto updateSchedule(String childId, String scheduleId, UpdateScheduleRuleRequest req);

  void deleteSchedule(String childId, String scheduleId);

  ContentRuleDto upsertContentRule(String childId, ContentCategory category, UpsertContentRuleRequest req);

  void replaceBlockedKeywords(String childId, ContentCategory category, List<String> keywords, String locale,
      String matchType);

  List<EnforcementEventDto> getChildHistory(String childId);

}
