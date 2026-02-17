package com.example.the_guardian_v1.controller;

import com.example.the_guardian_v1.dto.execute.*;
import com.example.the_guardian_v1.service.IExecuteService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/execute")
public class ExecuteController {

  private final IExecuteService executeService;
  public ExecuteController(IExecuteService executeService){ this.executeService = executeService; }

  @PostMapping
  public ExecuteResponse execute(@Valid @RequestBody ExecuteRequest request){ return executeService.execute(request); }
}
