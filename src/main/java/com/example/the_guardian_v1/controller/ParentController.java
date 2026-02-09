package com.example.the_guardian_v1.controller;

import com.example.the_guardian_v1.dto.parent.ChildrenListResponse;
import com.example.the_guardian_v1.dto.parent.LinkChildRequest;
import com.example.the_guardian_v1.service.IParentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/parents/me")
@Tag(name = "Parent", description = "Endpoints pour la gestion du profil parent et de ses enfants")
public class ParentController {
  private final IParentService parentService;

  public ParentController(IParentService parentService) {
    this.parentService = parentService;
  }

  @GetMapping("/children")
  @Operation(summary = "Lister mes enfants", description = "Retourne la liste des enfants associés au parent connecté.")
  public ChildrenListResponse myChildren() {
    return parentService.getMyChildren();
  }

  @PostMapping("/children/link")
  @Operation(summary = "Lier un enfant", description = "Associe un appareil enfant au parent connecté en utilisant l'ID de l'enfant.")
  public void linkChild(@Valid @RequestBody LinkChildRequest request) {
    parentService.linkChild(request);
  }
}
