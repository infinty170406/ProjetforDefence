package com.example.the_guardian_v1.dto.auth;
public class LoginResponse {
  public String accessToken;
  public String tokenType = "Bearer";
  public long expiresInSeconds;
  public ParentSummary parent;
  public static class ParentSummary {
    public String parentId;
    public String name;
    public String email;
  }
}
