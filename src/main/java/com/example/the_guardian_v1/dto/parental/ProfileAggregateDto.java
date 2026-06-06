package com.example.the_guardian_v1.dto.parental;
import java.util.List;
public class ProfileAggregateDto {
  public String childId;
  public ParentalProfileDto profile;
  public List<ScheduleRuleDto> scheduleRules;
  public List<ContentRuleDto> contentRules;
  public List<BlockedKeywordDto> blockedKeywords;
}
