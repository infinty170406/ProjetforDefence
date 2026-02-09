package com.example.the_guardian_v1.repository;

import com.example.the_guardian_v1.domain.model.Child;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface ChildRepository extends JpaRepository<Child, String> {
  List<Child> findByParentId(String parentId);
}
