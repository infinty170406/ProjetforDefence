package com.example.the_guardian_v1.service;

import com.example.the_guardian_v1.dto.parent.ChildrenListResponse;
import com.example.the_guardian_v1.dto.parent.LinkChildRequest;

public interface IParentService {
    ChildrenListResponse getMyChildren();

    void linkChild(LinkChildRequest request);
}
