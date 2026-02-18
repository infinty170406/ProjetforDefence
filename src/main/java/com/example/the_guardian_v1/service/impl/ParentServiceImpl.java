package com.example.the_guardian_v1.service.impl;

import com.example.the_guardian_v1.common.exception.ForbiddenException;
import com.example.the_guardian_v1.common.exception.NotFoundException;
import com.example.the_guardian_v1.domain.model.Child;
import com.example.the_guardian_v1.dto.parent.*;
import com.example.the_guardian_v1.repository.ChildRepository;
import com.example.the_guardian_v1.service.*;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class ParentServiceImpl implements IParentService {
  private final IAuthorizationService authorizationService;
  private final ChildRepository childRepository;

  public ParentServiceImpl(IAuthorizationService authorizationService, ChildRepository childRepository) {
    this.authorizationService = authorizationService;
    this.childRepository = childRepository;
  }

  @Override
  public void linkChild(LinkChildRequest request) {
    String parentId = authorizationService.getCurrentParentId();
    Child c = childRepository.findById(request.childId)
        .orElseThrow(() -> new NotFoundException(
            "L'appareil de l'enfant avec l'ID " + request.childId + " n'a pas été trouvé."));

    c.setParentId(parentId);
    childRepository.save(c);
  }

  @Override
  public ChildrenListResponse getMyChildren() {
    String parentId = authorizationService.getCurrentParentId();
    ChildrenListResponse r = new ChildrenListResponse();
    r.children = childRepository.findByParentId(parentId).stream().map(MappingUtils::toDto)
        .collect(Collectors.toList());
    return r;
  }

  @Override
  public ChildSummaryDto createChild(CreateChildRequest request) {
    String parentId = authorizationService.getCurrentParentId();
    Child c = new Child();
    c.setId(UUID.randomUUID().toString());
    c.setParentId(parentId);
    c.setDisplayName(request.getDisplayName());
    c.setAge(request.getAge());
    c.setStatus("OFFLINE");

    // Generate invitation token
    c.setInvitationToken(UUID.randomUUID().toString().replace("-", ""));
    c.setInvitationExpiresAt(Instant.now().plus(24, ChronoUnit.HOURS));

    Child saved = childRepository.save(c);
    return MappingUtils.toDto(saved);
  }

  @Override
  public ChildSummaryDto activateChild(String token) {
    Child c = childRepository.findByInvitationToken(token)
        .orElseThrow(() -> new NotFoundException("Invitation invalide ou introuvable"));

    if (c.getInvitationExpiresAt().isBefore(Instant.now())) {
      throw new ForbiddenException("L'invitation a expiré");
    }

    // Link device or update status
    c.setStatus("ACTIVE");
    c.setInvitationToken(null); // Consume token
    c.setInvitationExpiresAt(null);

    Child saved = childRepository.save(c);
    return MappingUtils.toDto(saved);
  }

  @Override
  public ChildSummaryDto updateChild(String childId, CreateChildRequest request) {
    String parentId = authorizationService.getCurrentParentId();
    Child c = childRepository.findById(childId)
        .orElseThrow(() -> new NotFoundException("Enfant non trouvé"));

    if (!c.getParentId().equals(parentId)) {
      throw new ForbiddenException("Non autorisé à modifier cet enfant");
    }

    c.setDisplayName(request.getDisplayName());
    c.setAge(request.getAge());

    Child updated = childRepository.save(c);
    return MappingUtils.toDto(updated);
  }

  @Override
  public void deleteChild(String childId) {
    String parentId = authorizationService.getCurrentParentId();
    Child c = childRepository.findById(childId)
        .orElseThrow(() -> new NotFoundException("Enfant non trouvé"));

    if (!c.getParentId().equals(parentId)) {
      throw new ForbiddenException("Non autorisé à supprimer cet enfant");
    }

    childRepository.delete(c);
  }
}
