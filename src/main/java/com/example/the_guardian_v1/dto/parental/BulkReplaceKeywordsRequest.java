package com.example.the_guardian_v1.dto.parental;

import lombok.Data;
import java.util.List;

@Data
public class BulkReplaceKeywordsRequest {
    public List<String> keywords;
    public String locale;
    public String matchType;
}
