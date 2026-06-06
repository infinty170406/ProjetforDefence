package com.example.the_guardian_v1.repository;

import com.example.the_guardian_v1.domain.model.EnforcementEvent;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface EnforcementEventRepository extends JpaRepository<EnforcementEvent, String> {
    List<EnforcementEvent> findByChildIdOrderByOccurredAtDesc(String childId);
}
