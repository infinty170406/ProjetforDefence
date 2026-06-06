package com.example.the_guardian_v1.service.impl;

import com.example.the_guardian_v1.domain.enums.*;
import com.example.the_guardian_v1.domain.model.EnforcementEvent;
import com.example.the_guardian_v1.dto.device.*;
import com.example.the_guardian_v1.repository.EnforcementEventRepository;
import com.example.the_guardian_v1.service.*;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.UUID;

@Service
public class DeviceServiceImpl implements IDeviceService {

  private final IParentalService parentalService;
  private final EnforcementEventRepository eventRepo;

  public DeviceServiceImpl(IParentalService parentalService, EnforcementEventRepository eventRepo) {
    this.parentalService = parentalService;
    this.eventRepo = eventRepo;
  }

  @Override
  public DeviceRulesResponse getRulesSnapshot(String childId) {
    DeviceRulesResponse r = new DeviceRulesResponse();
    r.childId = childId;
    r.generatedAt = Instant.now().toString();
    r.profileAggregate = parentalService.getProfileAggregate(childId);
    return r;
  }

  @Override
  public DeviceEventAckResponse ingestEvent(String childId, DeviceEventRequest req) {
    EnforcementEvent e = new EnforcementEvent();
    e.setId(UUID.randomUUID().toString());
    e.setChildId(childId);
    e.setType(EventType.DEVICE_EVENT_RECEIVED);
    e.setActor(ActorType.DEVICE);
    e.setOccurredAt(Instant.parse(req.occurredAt));
    e.setPayloadJson(req.payload == null ? "{}" : req.payload.toString());
    e.setCreatedAt(Instant.now());
    eventRepo.save(e);

    DeviceEventAckResponse ack = new DeviceEventAckResponse();
    ack.accepted = true;
    ack.serverReceivedAt = Instant.now().toString();
    return ack;
  }
}
