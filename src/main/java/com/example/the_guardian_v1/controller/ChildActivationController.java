package com.example.the_guardian_v1.controller;

import com.example.the_guardian_v1.dto.child.ChildActivationRequest;
import com.example.the_guardian_v1.dto.parent.ChildSummaryDto;
import com.example.the_guardian_v1.service.IParentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/children")
@Tag(name = "Child Activation", description = "Endpoints publics pour l'activation des appareils enfants")
public class ChildActivationController {

    private final IParentService parentService;

    public ChildActivationController(IParentService parentService) {
        this.parentService = parentService;
    }

    @PostMapping("/activate")
    @Operation(summary = "Activer un appareil enfant", description = "Associe un appareil en utilisant un token d'invitation valide.")
    public ChildSummaryDto activate(@Valid @RequestBody ChildActivationRequest request) {
        return parentService.activateChild(request.getToken());
    }
}
