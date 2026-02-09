package com.example.the_guardian_v1.common.error;

import com.example.the_guardian_v1.common.exception.*;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.*;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.*;

@RestControllerAdvice
public class GlobalExceptionHandler {

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ApiErrorResponse> handleValidation(MethodArgumentNotValidException ex, HttpServletRequest req) {
    ApiErrorResponse r = base(400, "VALIDATION_ERROR", "Validation failed", req);
    List<Map<String, String>> fieldErrors = new ArrayList<>();
    ex.getBindingResult().getFieldErrors().forEach(fe -> {
      Map<String, String> m = new HashMap<>();
      m.put("field", fe.getField());
      m.put("reason", fe.getDefaultMessage());
      fieldErrors.add(m);
    });
    Map<String, Object> details = new HashMap<>();
    details.put("fieldErrors", fieldErrors);
    r.details = details;
    return ResponseEntity.badRequest().body(r);
  }

  @ExceptionHandler(UnauthorizedException.class)
  public ResponseEntity<ApiErrorResponse> handleUnauthorized(UnauthorizedException ex, HttpServletRequest req) {
    return ResponseEntity.status(401).body(base(401, "UNAUTHORIZED", ex.getMessage(), req));
  }

  @ExceptionHandler(ForbiddenException.class)
  public ResponseEntity<ApiErrorResponse> handleForbidden(ForbiddenException ex, HttpServletRequest req) {
    return ResponseEntity.status(403).body(base(403, "FORBIDDEN", ex.getMessage(), req));
  }

  @ExceptionHandler(NotFoundException.class)
  public ResponseEntity<ApiErrorResponse> handleNotFound(NotFoundException ex, HttpServletRequest req) {
    return ResponseEntity.status(404).body(base(404, "NOT_FOUND", ex.getMessage(), req));
  }

  @ExceptionHandler(ConflictException.class)
  public ResponseEntity<ApiErrorResponse> handleConflict(ConflictException ex, HttpServletRequest req) {
    return ResponseEntity.status(409).body(base(409, "CONFLICT", ex.getMessage(), req));
  }

  @ExceptionHandler(ValidationException.class)
  public ResponseEntity<ApiErrorResponse> handleDomainValidation(ValidationException ex, HttpServletRequest req) {
    return ResponseEntity.status(422).body(base(422, "UNPROCESSABLE", ex.getMessage(), req));
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<ApiErrorResponse> handleGeneric(Exception ex, HttpServletRequest req) {
    return ResponseEntity.status(500).body(base(500, "INTERNAL_ERROR", "Unexpected error", req));
  }

  private ApiErrorResponse base(int status, String error, String message, HttpServletRequest req) {
    ApiErrorResponse r = new ApiErrorResponse();
    r.timestamp = Instant.now().toString();
    r.status = status;
    r.error = error;
    r.message = message;
    r.path = req.getRequestURI();
    return r;
  }
}
