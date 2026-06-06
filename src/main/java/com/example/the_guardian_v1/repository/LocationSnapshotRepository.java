package com.example.the_guardian_v1.repository;

import com.example.the_guardian_v1.domain.model.LocationSnapshot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface LocationSnapshotRepository extends JpaRepository<LocationSnapshot, Long> {

    /**
     * Returns the most recent location for a child.
     */
    @Query("SELECT l FROM LocationSnapshot l WHERE l.childId = :childId ORDER BY l.capturedAt DESC LIMIT 1")
    Optional<LocationSnapshot> findLatestByChildId(String childId);
}
