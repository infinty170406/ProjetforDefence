package com.example.the_guardian.auth.dto.response;

import jakarta.validation.constraints.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChildDto {
    private String id;
    private String firstName;
    private String lastName;
    private Integer age;
    private String deviceId;
    private Boolean active;
    private LocalDateTime createdAt;
}
