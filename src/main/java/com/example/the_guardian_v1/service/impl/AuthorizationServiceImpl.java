package com.example.the_guardian_v1.service.impl;

import com.example.the_guardian_v1.common.exception.*;
import com.example.the_guardian_v1.domain.model.Child;
import com.example.the_guardian_v1.repository.ChildRepository;
import com.example.the_guardian_v1.service.IAuthorizationService;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

@Service
public class AuthorizationServiceImpl implements IAuthorizationService {

  private final ChildRepository childRepository;

  public AuthorizationServiceImpl(ChildRepository childRepository) { this.childRepository = childRepository; }

  @Override
  public String getCurrentParentId() {
    Authentication a = SecurityContextHolder.getContext().getAuthentication();
    if (a == null || a.getPrincipal() == null) return null;
    return a.getPrincipal().toString();
  }

  @Override
  public void assertCurrentParentOwnsChild(String childId) {
    String parentId = getCurrentParentId();
    if (parentId == null) throw new ForbiddenException("Not authenticated");
    assertParentOwnsChild(parentId, childId);
  }

  @Override
  public void assertParentOwnsChild(String parentId, String childId) {
    Child c = childRepository.findById(childId).orElseThrow(() -> new NotFoundException("Child not found"));
    if (!parentId.equals(c.getParentId())) throw new ForbiddenException("You do not own this child");
  }
}
