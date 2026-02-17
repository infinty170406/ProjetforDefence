<<<<<<< HEAD
package com.example.the_guardian_v1.service.impl;

import com.example.the_guardian_v1.common.exception.ValidationException;
import com.example.the_guardian_v1.domain.enums.ContentCategory;
import com.example.the_guardian_v1.dto.execute.*;
import com.example.the_guardian_v1.dto.parental.*;
import com.example.the_guardian_v1.service.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class ExecuteServiceImpl implements IExecuteService {

  private final ObjectMapper objectMapper;
  private final IParentalService parentalService;
  private final IParentService parentService;

  public ExecuteServiceImpl(ObjectMapper objectMapper, IParentalService parentalService, IParentService parentService) {
    this.objectMapper = objectMapper;
    this.parentalService = parentalService;
    this.parentService = parentService;
  }

  @Override
  public ExecuteResponse execute(ExecuteRequest request) {
    String intent = request.intent == null ? "" : request.intent.trim().toUpperCase();

    ExecuteResponse resp = new ExecuteResponse();
    resp.requestId = request.requestId;

    switch (intent) {
      case "UPSERT_CONTENT_POLICY" -> {
        UpsertContentPolicyParams p = objectMapper.convertValue(request.parameters, UpsertContentPolicyParams.class);

        ContentCategory category;
        try {
          category = ContentCategory.valueOf(p.category.trim().toUpperCase());
        } catch (Exception e) {
          throw new ValidationException("Invalid category: " + p.category);
        }

        UpsertContentRuleRequest cr = new UpsertContentRuleRequest();
        cr.action = p.action;
        cr.confidenceThreshold = p.confidenceThreshold;
        cr.enabled = p.enabled;

        var ruleDto = parentalService.upsertContentRule(request.childId, category, cr);

        List<String> keywords = (p.keywords == null) ? List.of() : p.keywords;
        parentalService.replaceBlockedKeywords(request.childId, category, keywords, p.locale, p.keywordMatch);

        resp.status = "SUCCESS";
        resp.message = "Content policy applied";
        resp.data = java.util.Map.of(
            "contentRule", ruleDto,
            "keywordsCount", keywords.size(),
            "category", category.name());
      }
      case "UPDATE_PROFILE" -> {
        UpdateProfileParams p = objectMapper.convertValue(request.parameters, UpdateProfileParams.class);
        UpdateParentalProfileRequest upr = new UpdateParentalProfileRequest();
        upr.enabled = p.enabled;
        upr.mode = p.mode;
        upr.timezone = p.timezone;

        var profile = parentalService.updateProfile(request.childId, upr);
        resp.status = "SUCCESS";
        resp.message = "Profile updated";
        resp.data = java.util.Map.of("profile", profile);
      }
      case "CREATE_SCHEDULE" -> {
        CreateScheduleParams p = objectMapper.convertValue(request.parameters, CreateScheduleParams.class);
        CreateScheduleRuleRequest csr = new CreateScheduleRuleRequest();
        csr.daysOfWeek = p.daysOfWeek;
        csr.startTime = p.startTime;
        csr.endTime = p.endTime;
        csr.action = p.action;
        csr.enabled = p.enabled;

        var schedule = parentalService.createSchedule(request.childId, csr);
        resp.status = "SUCCESS";
        resp.message = "Schedule created";
        resp.data = java.util.Map.of("schedule", schedule);
      }
      case "CREATE_CHILD" -> {
        CreateChildParams p = objectMapper.convertValue(request.parameters, CreateChildParams.class);
        if (request.parentId == null || request.parentId.isBlank()) {
          throw new ValidationException("parentId is required for CREATE_CHILD intent");
        }
        var child = parentService.createChildForParent(request.parentId, p.name, p.age);
        resp.status = "SUCCESS";
        resp.message = "Child profile created";
        resp.data = java.util.Map.of("child", child);
      }
      default -> throw new ValidationException("Unknown intent: " + intent);
    }
    return resp;
  }
}
=======
package com.example.the_guardian_v1.service.impl;

import com.example.the_guardian_v1.common.exception.ValidationException;
import com.example.the_guardian_v1.domain.enums.ContentCategory;
import com.example.the_guardian_v1.dto.execute.*;
import com.example.the_guardian_v1.dto.parental.*;
import com.example.the_guardian_v1.service.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class ExecuteServiceImpl implements IExecuteService {

  private final ObjectMapper objectMapper;
  private final IParentalService parentalService;

  public ExecuteServiceImpl(ObjectMapper objectMapper, IParentalService parentalService) {
    this.objectMapper = objectMapper;
    this.parentalService = parentalService;
  }

  @Override
  public ExecuteResponse execute(ExecuteRequest request) {
    String intent = request.intent == null ? "" : request.intent.trim().toUpperCase();

    ExecuteResponse resp = new ExecuteResponse();
    resp.requestId = request.requestId;

    switch (intent) {
      case "UPSERT_CONTENT_POLICY" -> {
        UpsertContentPolicyParams p = objectMapper.convertValue(request.parameters, UpsertContentPolicyParams.class);

        ContentCategory category;
        try { category = ContentCategory.valueOf(p.category.trim().toUpperCase()); }
        catch (Exception e) { throw new ValidationException("Invalid category: " + p.category); }

        UpsertContentRuleRequest cr = new UpsertContentRuleRequest();
        cr.action = p.action;
        cr.confidenceThreshold = p.confidenceThreshold;
        cr.enabled = p.enabled;

        var ruleDto = parentalService.upsertContentRule(request.childId, category, cr);

        List<String> keywords = (p.keywords == null) ? List.of() : p.keywords;
        parentalService.replaceBlockedKeywords(request.childId, category, keywords, p.locale, p.keywordMatch);

        resp.status = "SUCCESS";
        resp.message = "Content policy applied";
        resp.data = java.util.Map.of(
            "contentRule", ruleDto,
            "keywordsCount", keywords.size(),
            "category", category.name()
        );
      }
      case "UPDATE_PROFILE" -> {
        UpdateProfileParams p = objectMapper.convertValue(request.parameters, UpdateProfileParams.class);
        UpdateParentalProfileRequest upr = new UpdateParentalProfileRequest();
        upr.enabled = p.enabled;
        upr.mode = p.mode;
        upr.timezone = p.timezone;

        var profile = parentalService.updateProfile(request.childId, upr);
        resp.status = "SUCCESS";
        resp.message = "Profile updated";
        resp.data = java.util.Map.of("profile", profile);
      }
      case "CREATE_SCHEDULE" -> {
        CreateScheduleParams p = objectMapper.convertValue(request.parameters, CreateScheduleParams.class);
        CreateScheduleRuleRequest csr = new CreateScheduleRuleRequest();
        csr.daysOfWeek = p.daysOfWeek;
        csr.startTime = p.startTime;
        csr.endTime = p.endTime;
        csr.action = p.action;
        csr.enabled = p.enabled;

        var schedule = parentalService.createSchedule(request.childId, csr);
        resp.status = "SUCCESS";
        resp.message = "Schedule created";
        resp.data = java.util.Map.of("schedule", schedule);
      }
      default -> throw new ValidationException("Unknown intent: " + intent);
    }
    return resp;
  }
}
>>>>>>> 707db64 (Fix: align ports and database URL for Render deployment)
