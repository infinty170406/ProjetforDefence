package com.example.the_guardian.auth.dto.response;

import jakarta.validation.constraints.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserInfo {
    private String id;
    private String email;
    private String firstName;
    private String lastName;
    private String role;
    private List<ChildDto> children;
}
