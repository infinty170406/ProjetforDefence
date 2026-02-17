<<<<<<< HEAD
package com.example.the_guardian_v1.service;

import com.example.the_guardian_v1.dto.parent.ChildSummaryDto;
import com.example.the_guardian_v1.dto.parent.ChildrenListResponse;
import com.example.the_guardian_v1.dto.parent.LinkChildRequest;

public interface IParentService {
    ChildrenListResponse getMyChildren();

    void linkChild(LinkChildRequest request);

    ChildSummaryDto createChild(String name, Integer age);

    ChildSummaryDto createChildForParent(String parentId, String name, Integer age);
}
=======
package com.example.the_guardian_v1.service;

import com.example.the_guardian_v1.dto.parent.ChildrenListResponse;
import com.example.the_guardian_v1.dto.parent.LinkChildRequest;

public interface IParentService {
    ChildrenListResponse getMyChildren();

    void linkChild(LinkChildRequest request);

    ChildSummaryDto createChild(CreateChildRequest request);

    ChildSummaryDto updateChild(String childId, CreateChildRequest request);

    void deleteChild(String childId);
}
>>>>>>> 707db64 (Fix: align ports and database URL for Render deployment)
