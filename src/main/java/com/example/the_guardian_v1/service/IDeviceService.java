package com.example.the_guardian_v1.service;
import com.example.the_guardian_v1.dto.device.*;


public interface IDeviceService {
  DeviceRulesResponse getRulesSnapshot(String childId);
  DeviceEventAckResponse ingestEvent(String childId, DeviceEventRequest req);

}
