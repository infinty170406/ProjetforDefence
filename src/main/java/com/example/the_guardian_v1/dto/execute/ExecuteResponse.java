package com.example.the_guardian_v1.dto.execute;
import java.util.List;
public class ExecuteResponse {
  public String requestId;
  public String status;
  public String message;
  public Object data;
  public List<ExecuteError> errors;
  public static class ExecuteError { public String code; public String message; }
}
