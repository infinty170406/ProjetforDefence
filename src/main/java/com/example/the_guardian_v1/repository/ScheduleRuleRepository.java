package com.example.the_guardian_v1.repository;

import com.example.the_guardian_v1.domain.model.ScheduleRule;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface ScheduleRuleRepository extends JpaRepository<ScheduleRule, String> {
  List<ScheduleRule> findByChildId(String childId);
}
