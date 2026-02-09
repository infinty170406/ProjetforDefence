package com.example.the_guardian_v1.controller;

import com.example.the_guardian_v1.dto.device.*;
import com.example.the_guardian_v1.service.IDeviceService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/device/children/{childId}")
public class DeviceController {

  private final IDeviceService deviceService;
  public DeviceController(IDeviceService deviceService){ this.deviceService = deviceService; }

  @GetMapping("/rules")
  public DeviceRulesResponse getRules(@PathVariable String childId){ return deviceService.getRulesSnapshot(childId); }

  @PostMapping("/events")
  @ResponseStatus(HttpStatus.ACCEPTED)
  public DeviceEventAckResponse postEvent(@PathVariable String childId, @Valid @RequestBody DeviceEventRequest req){
    return deviceService.ingestEvent(childId, req);
  }
}
