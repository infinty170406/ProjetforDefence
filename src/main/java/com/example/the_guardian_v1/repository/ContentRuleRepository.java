package com.example.the_guardian_v1.repository;

import com.example.the_guardian_v1.domain.enums.ContentCategory;
import com.example.the_guardian_v1.domain.model.ContentRule;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;

public interface ContentRuleRepository extends JpaRepository<ContentRule, String> {
  Optional<ContentRule> findByChildIdAndCategory(String childId, ContentCategory category);
  List<ContentRule> findByChildId(String childId);
}
