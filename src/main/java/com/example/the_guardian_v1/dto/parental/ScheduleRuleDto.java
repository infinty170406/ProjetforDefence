package com.example.the_guardian_v1.dto.parental;
import java.util.List;
public class ScheduleRuleDto {
  public String scheduleId;
  public String childId;
  public List<String> daysOfWeek;
  public String startTime;
  public String endTime;
  public String action;
  public boolean enabled;
  public String updatedAt;
}
