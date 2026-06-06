package com.example.the_guardian_v1.repository;

import com.example.the_guardian_v1.domain.model.GeofenceEvent;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface GeofenceEventRepository extends JpaRepository<GeofenceEvent, Long> {

    Page<GeofenceEvent> findByChildIdOrderByOccurredAtDesc(String childId, Pageable pageable);

    Page<GeofenceEvent> findByParentIdOrderByOccurredAtDesc(String parentId, Pageable pageable);
}
