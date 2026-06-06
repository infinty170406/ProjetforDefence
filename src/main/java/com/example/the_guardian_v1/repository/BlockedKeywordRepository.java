package com.example.the_guardian_v1.repository;

import com.example.the_guardian_v1.domain.enums.ContentCategory;
import com.example.the_guardian_v1.domain.model.BlockedKeyword;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface BlockedKeywordRepository extends JpaRepository<BlockedKeyword, String> {
  List<BlockedKeyword> findByChildIdAndCategory(String childId, ContentCategory category);
  void deleteByChildIdAndCategory(String childId, ContentCategory category);
}
