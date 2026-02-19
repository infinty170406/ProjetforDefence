package com.example.the_guardian_v1.repository;

import com.example.the_guardian_v1.domain.model.Child;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface ChildRepository extends JpaRepository<Child, String> {
  List<Child> findByParentId(String parentId);

  Optional<Child> findByInvitationToken(String invitationToken);
}
