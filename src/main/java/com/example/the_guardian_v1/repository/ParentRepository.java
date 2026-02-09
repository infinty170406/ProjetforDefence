package com.example.the_guardian_v1.repository;

import com.example.the_guardian_v1.domain.model.Parent;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface ParentRepository extends JpaRepository<Parent, String> {
  Optional<Parent> findByEmail(String email);
}
