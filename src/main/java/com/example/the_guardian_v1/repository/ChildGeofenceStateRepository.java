package com.example.the_guardian_v1.repository;

import com.example.the_guardian_v1.domain.model.ChildGeofenceState;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ChildGeofenceStateRepository extends JpaRepository<ChildGeofenceState, Long> {

    Optional<ChildGeofenceState> findByChildIdAndGeofenceId(String childId, Long geofenceId);
}
