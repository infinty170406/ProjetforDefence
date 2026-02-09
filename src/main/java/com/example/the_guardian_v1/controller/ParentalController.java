package com.example.the_guardian_v1.controller;

import com.example.the_guardian_v1.domain.enums.ContentCategory;
import com.example.the_guardian_v1.dto.parental.*;
import com.example.the_guardian_v1.service.IParentalService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/children/{childId}/parental")
public class ParentalController {

  private final IParentalService parentalService;

  public ParentalController(IParentalService parentalService) {
    this.parentalService = parentalService;
  }

  @GetMapping("/profile")
  public ProfileAggregateDto getProfile(@PathVariable String childId) {
    return parentalService.getProfileAggregate(childId);
  }

  @PutMapping("/profile")
  public ParentalProfileDto updateProfile(@PathVariable String childId,
      @Valid @RequestBody UpdateParentalProfileRequest req) {
    return parentalService.updateProfile(childId, req);
  }

  @PostMapping("/schedules")
  @ResponseStatus(HttpStatus.CREATED)
  public ScheduleRuleDto createSchedule(@PathVariable String childId,
      @Valid @RequestBody CreateScheduleRuleRequest req) {
    return parentalService.createSchedule(childId, req);
  }

  @PutMapping("/schedules/{scheduleId}")
  public ScheduleRuleDto updateSchedule(@PathVariable String childId, @PathVariable String scheduleId,
      @Valid @RequestBody UpdateScheduleRuleRequest req) {
    return parentalService.updateSchedule(childId, scheduleId, req);
  }

  @DeleteMapping("/schedules/{scheduleId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void deleteSchedule(@PathVariable String childId, @PathVariable String scheduleId) {
    parentalService.deleteSchedule(childId, scheduleId);
  }

  @PutMapping("/content/{category}")
  public ContentRuleDto upsertContentRule(@PathVariable String childId, @PathVariable String category,
      @Valid @RequestBody UpsertContentRuleRequest req) {
    ContentCategory c = parseCategory(category);
    return parentalService.upsertContentRule(childId, c, req);
  }

  @PutMapping("/content/{category}/keywords")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void replaceKeywords(@PathVariable String childId, @PathVariable String category,
      @Valid @RequestBody BulkReplaceKeywordsRequest req) {
    ContentCategory c = parseCategory(category);
    parentalService.replaceBlockedKeywords(childId, c, req.keywords, req.locale, req.matchType);
  }

  private ContentCategory parseCategory(String category) {
    try {
      return ContentCategory.valueOf(category.trim().toUpperCase());
    } catch (Exception e) {
      throw new com.example.the_guardian_v1.common.exception.ValidationException("Invalid category: " + category);
    }
  }
}
