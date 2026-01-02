package com.example.the_guardian.auth.repository;

import com.example.the_guardian.auth.entity.Parent;
import com.example.the_guardian.auth.entity.Child;
import com.example.the_guardian.auth.entity.RefreshToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ChildRepository extends JpaRepository<Child, String> {

    List<Child> findByParentId(String parentId);

    Optional<Child> findByDeviceId(String deviceId);

    Boolean existsByDeviceId(String deviceId);

    List<Child> findByParentIdAndActiveTrue(String parentId);
}
