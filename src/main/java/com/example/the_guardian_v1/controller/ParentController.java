package com.example.the_guardian_v1.controller;

import com.example.the_guardian_v1.dto.parent.ChildrenListResponse;
import com.example.the_guardian_v1.service.IParentService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/parents/me")
public class ParentController {
  private final IParentService parentService;
  public ParentController(IParentService parentService){ this.parentService = parentService; }

  @GetMapping("/children")
  public ChildrenListResponse myChildren(){ return parentService.getMyChildren(); }

}
