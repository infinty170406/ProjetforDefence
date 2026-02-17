package com.example.the_guardian_v1.service;

import com.example.the_guardian_v1.dto.parent.*;

public interface IParentService {
    ChildrenListResponse getMyChildren();

    void linkChild(LinkChildRequest request);

    ChildSummaryDto createChild(CreateChildRequest request);

    ChildSummaryDto updateChild(String childId, CreateChildRequest request);

    void deleteChild(String childId);
}
