package com.example.the_guardian_v1.dto.device;
import jakarta.validation.constraints.NotBlank;
public class DeviceEventRequest {
  @NotBlank public String eventId;
  @NotBlank public String type;
  @NotBlank public String occurredAt;
  public Object payload;
  public String source = "DEVICE";
}
