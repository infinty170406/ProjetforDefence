package com.example.the_guardian_v1.repository;

import com.example.the_guardian_v1.domain.model.Geofence;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface GeofenceRepository extends JpaRepository<Geofence, Long> {

    List<Geofence> findByParentIdAndActiveTrue(String parentId);

    /**
     * Returns all active geofences that apply to a given child:
     * either explicitly assigned to this child OR targeting all children (childId =
     * null) of the parent.
     */
    List<Geofence> findByParentIdAndActiveTrueAndChildIdIsNullOrParentIdAndActiveTrueAndChildId(
            String parentId1, String parentId2, String childId);
}
