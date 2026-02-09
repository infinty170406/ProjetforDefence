package com.example.the_guardian_v1.dto.execute;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;
public class CreateScheduleParams {
  @NotEmpty public List<String> daysOfWeek;
  @NotBlank public String startTime;
  @NotBlank public String endTime;
  @NotBlank public String action;
  public Boolean enabled = true;
}
