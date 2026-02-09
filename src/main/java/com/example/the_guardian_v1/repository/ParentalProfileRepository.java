package com.example.the_guardian_v1.repository;

import com.example.the_guardian_v1.domain.model.ParentalProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface ParentalProfileRepository extends JpaRepository<ParentalProfile, String> {
  Optional<ParentalProfile> findByChildId(String childId);
}
