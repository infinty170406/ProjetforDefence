package com.example.the_guardian_v1.service.impl;

import com.example.the_guardian_v1.common.exception.NotFoundException;
import com.example.the_guardian_v1.domain.model.Child;
import com.example.the_guardian_v1.dto.parent.*;
import com.example.the_guardian_v1.repository.ChildRepository;
import com.example.the_guardian_v1.service.*;
import org.springframework.stereotype.Service;

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
  public ChildSummaryDto createChild(String name, Integer age) {
    String parentId = authorizationService.getCurrentParentId();
    return createChildForParent(parentId, name, age);
  }

  @Override
  public ChildSummaryDto createChildForParent(String parentId, String name, Integer age) {
    Child c = new Child();
    c.setId(java.util.UUID.randomUUID().toString());
    c.setParentId(parentId);
    c.setDisplayName(name);
    c.setAge(age);
    c.setStatus("ACTIVE");
    c = childRepository.save(c);
    return MappingUtils.toDto(c);
  }
}
