package com.example.the_guardian_v1.controller;

import com.example.the_guardian_v1.dto.parental.EnforcementEventDto;
import com.example.the_guardian_v1.service.IParentalService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/children/{childId}/history")
@Tag(name = "History", description = "Endpoints pour l'historique d'activité et de protection")
public class HistoryController {

    private final IParentalService parentalService;

    public HistoryController(IParentalService parentalService) {
        this.parentalService = parentalService;
    }

    @GetMapping
    @Operation(summary = "Récupérer l'historique d'un enfant", description = "Retourne la liste des événements de protection et d'activité, triés par date décroissante.")
    public List<EnforcementEventDto> getHistory(@PathVariable String childId) {
        return parentalService.getChildHistory(childId);
    }
}
