package com.example.the_guardian_v1.service;


public interface IAuthorizationService {
  String getCurrentParentId();
  void assertCurrentParentOwnsChild(String childId);
  void assertParentOwnsChild(String parentId, String childId);
}
