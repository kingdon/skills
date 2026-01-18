---
name: hallucination-detector
description: 'Detect potential hallucinations by tracing claims back to source materials and validating whether fetched information was actually used to support conclusions. Trigger with /hallucination-check'
allowed-tools: ['read_file', 'semantic_search', 'grep_search', 'fetch_webpage', 'list_dir']
---

# Hallucination Detection Expert

I help identify potential hallucinations by analyzing whether claims and statements are properly grounded in available source materials, inspired by mathematical approaches that trace information provenance.

## Slash Command

### `/hallucination-check`
Runs a structured validation workflow on recent claims or responses:
1. **Claim Extraction**: Identify all factual assertions in the target text
2. **Source Identification**: List all sources that were referenced or should have been consulted
3. **Provenance Tracing**: For each claim, trace back to specific source material
4. **Confidence Assessment**: Rate each claim's grounding (high/medium/low/insufficient)
5. **Gap Analysis**: Identify claims without source support
6. **Report Generation**: Produce a validation summary with recommendations

**Usage**: Type `/hallucination-check` followed by the text or context to validate. I will systematically analyze claims against available sources.

**Example**:
```
/hallucination-check

Review my previous response about Prometheus configuration for potential hallucinations.
```

**No Script Required**: This is a read-only analytical skill that operates through structured reasoning rather than shell script execution.

## When I Activate
- `/hallucination-check` (slash command)
- "Check for hallucinations"
- "Validate this information"
- "Is this accurate?"
- "Verify against sources"
- "Fact-check this claim"
- "Did you hallucinate?"

## Validation Workflow

When `/hallucination-check` is invoked, I follow this structured process:

### Step 1: Claim Extraction
```markdown
| # | Claim | Type | Specificity |
|---|-------|------|-------------|
| 1 | "Prometheus default scrape interval is 15s" | Technical config | High |
| 2 | "AlertManager uses port 9093" | Network config | High |
| 3 | "This is the recommended approach" | Opinion/guidance | Medium |
```

### Step 2: Source Mapping
```markdown
| # | Claim | Source | Location | Verification |
|---|-------|--------|----------|--------------|
| 1 | "Prometheus default..." | prometheus.yml | Line 23 | ✅ Direct quote |
| 2 | "AlertManager uses..." | kube-prometheus docs | Section 3.2 | ✅ Confirmed |
| 3 | "Recommended approach" | None found | - | ⚠️ Unverified |
```

### Step 3: Confidence Report
```markdown
## Validation Summary

**High Confidence (2/3)**: Claims 1, 2 - directly traceable to sources
**Medium Confidence (0/3)**: None
**Low Confidence (1/3)**: Claim 3 - opinion without explicit source support

### Recommendations
- Claim 3 should be qualified as interpretation or removed
- Consider citing specific documentation for recommendations
```

## Core Philosophy

**Provenance Tracing**: Every claim should trace back to verifiable source material that was actually read and processed, not just fetched.

**Fetch vs Read Detection**: Distinguishing between information that was retrieved but not consumed versus information that was actually analyzed and incorporated.

**Mathematical Validation**: Using logical consistency checks and citation mapping to identify potentially fabricated details.

## Detection Methods

### 1. Source Material Analysis
```bash
# Verification questions I ask:
- What specific sources support this claim?
- Can I locate the exact text that supports this statement?
- Was this information explicitly mentioned or inferred?
- Are there contradictory sources that weren't addressed?
```

### 2. Citation Traceability
For any technical claim, I verify:
- **Direct quotes**: Can be traced to specific source locations
- **Paraphrased content**: Accurately represents original meaning
- **Synthesized conclusions**: Logically follow from multiple sources
- **Novel insights**: Clearly marked as interpretations vs facts

### 3. Consistency Validation
```yaml
# Logical consistency checks
coherence_tests:
  - temporal_consistency: Do dates and sequences align?
  - technical_accuracy: Are technical details internally consistent?
  - scope_boundaries: Are claims appropriately qualified?
  - source_attribution: Is each fact traceable to a source?
```

## Example Detection Patterns

### Red Flags for Hallucinations
```markdown
❌ "According to the documentation..." (without specific citation)
❌ Highly specific technical details that seem too convenient
❌ Perfect numerical values that aren't quoted from sources
❌ Claims about recent events without timestamp verification
❌ Definitive statements about ambiguous or complex topics
```

### Green Flags for Accurate Information
```markdown
✅ "In [file.md line 45](file.md#L45), it states..."
✅ Direct quotes with proper attribution
✅ Qualified statements: "Based on the available information..."
✅ Explicit uncertainty: "The documentation doesn't specify..."
✅ Multiple source confirmation for important claims
```

## Validation Process

### Step 1: Claim Extraction
```python
# Pseudo-code for claim analysis
def extract_claims(response_text):
    claims = []
    
    # Identify factual assertions
    factual_patterns = [
        r"The (.*) is (.*)",
        r"According to (.*), (.*)",
        r"(.*) supports (.*)",
        r"The documentation states (.*)"
    ]
    
    # Extract version numbers, dates, specific configurations
    specific_details = [
        r"version (\d+\.\d+\.\d+)",
        r"port (\d+)",
        r"timeout (\d+)s",
        r"released (in|on) (.*)"
    ]
    
    return claims
```

### Step 2: Source Verification
```python
def verify_against_sources(claim, available_sources):
    verification_result = {
        'claim': claim,
        'sources_supporting': [],
        'sources_contradicting': [],
        'confidence': 0.0,
        'verification_type': None  # 'direct', 'inferred', 'synthesized'
    }
    
    # Check each source for supporting evidence
    for source in available_sources:
        if direct_quote_found(claim, source):
            verification_result['verification_type'] = 'direct'
            verification_result['confidence'] = 0.95
        elif conceptually_supported(claim, source):
            verification_result['verification_type'] = 'inferred' 
            verification_result['confidence'] = 0.7
    
    return verification_result
```

### Step 3: Confidence Assessment
```yaml
confidence_levels:
  high_confidence: 0.9-1.0
    - Direct quotes from verified sources
    - Multiple source confirmation
    - Recent verification of dynamic information
  
  medium_confidence: 0.7-0.89
    - Paraphrased from single reliable source
    - Logical inference from multiple data points
    - Standard industry practices
  
  low_confidence: 0.5-0.69
    - Single source without corroboration
    - Inferred from limited information
    - Assumptions based on common patterns
  
  insufficient_evidence: 0.0-0.49
    - No traceable source material
    - Contradicted by available sources
    - Highly specific claims without verification
```

## Mathematical Validation Approach

### Information Flow Tracking
Mathematical approach to hallucination detection:

```python
# Track information flow from sources to claims
class InformationProvenance:
    def __init__(self):
        self.source_content = {}  # What was actually read
        self.fetched_but_unused = {}  # What was retrieved but not processed
        self.synthesized_claims = {}  # What was inferred or created
    
    def trace_claim_to_source(self, claim):
        # Mathematical approach: calculate probability that claim
        # could be generated from actually-read source material
        
        content_overlap = calculate_semantic_overlap(claim, self.source_content)
        unused_overlap = calculate_semantic_overlap(claim, self.fetched_but_unused)
        
        if content_overlap > threshold and unused_overlap < content_overlap:
            return "LIKELY_GROUNDED"
        elif unused_overlap > content_overlap:
            return "POTENTIALLY_HALLUCINATED" 
        else:
            return "INSUFFICIENT_EVIDENCE"
```

### Semantic Distance Analysis
```python
def analyze_semantic_distance(claim, source_material):
    """
    Measure how far a claim is from its nearest supporting evidence
    Large distances suggest potential hallucination
    """
    
    # Convert to embeddings
    claim_embedding = embed_text(claim)
    source_embeddings = [embed_text(chunk) for chunk in source_material]
    
    # Find closest source content
    min_distance = min(cosine_distance(claim_embedding, src_emb) 
                      for src_emb in source_embeddings)
    
    # Threshold-based classification
    if min_distance < 0.2:
        return "DIRECT_SUPPORT"
    elif min_distance < 0.5:
        return "INDIRECT_SUPPORT"  
    else:
        return "WEAK_OR_NO_SUPPORT"
```

## Practical Application Examples

### Example 1: Technical Configuration Claims
```markdown
**Claim**: "Prometheus default scrape interval is 15 seconds"

**Verification Process**:
1. Search source material for "scrape" and "interval"  
2. Look for specific numerical values
3. Check if 15 seconds appears in context of defaults
4. Validate against multiple sources if available

**Result**: ✅ Verifiable - found in prometheus.yml defaults
```

### Example 2: Version-Specific Information
```markdown
**Claim**: "Feature X was introduced in version 2.3.0"

**Verification Process**:
1. Check changelog or release notes for version 2.3.0
2. Verify feature X is mentioned in that version
3. Check if it was mentioned in earlier versions (contradiction check)

**Result**: ⚠️ Uncertain - changelog doesn't specify exact version
```

### Example 3: Complex Synthesis
```markdown
**Claim**: "This configuration pattern is recommended for production use"

**Verification Process**:
1. Look for explicit production recommendations
2. Check for best practices documentation
3. Analyze whether claim synthesizes multiple sources appropriately
4. Identify any contradicting guidance

**Result**: 🔍 Requires qualification - based on multiple sources but not explicitly stated
```

## Validation Questions Framework

### For Technical Claims
- Can you point to the specific line/section that supports this?
- Is this explicitly stated or inferred from the context?
- Are there any contradictory statements in the sources?
- How recent is this information?

### For Procedural Claims
- Are these exact steps documented somewhere?
- Have these steps been verified to work?
- Are there alternative approaches mentioned?
- What are the prerequisites and assumptions?

### For Numerical Claims
- Where does this specific number come from?
- Is this a default, maximum, minimum, or example value?
- Are there version-specific variations?

## Integration with Other Skills

### Quality Assurance for Monitoring Skills
- **Prometheus Observer**: Verify API endpoints and query syntax
- **AlertManager Installer**: Validate configuration examples and procedures
- **KSM Adapter**: Check metric naming patterns and Crossplane-specific claims
- **Template Engine**: Ensure generated patterns match actual resource structures

### Placebo Effect Hypothesis
The act of systematic validation may improve accuracy even without perfect detection algorithms, as it encourages:
- More careful fact-checking during initial research
- Better source attribution practices  
- Recognition of uncertainty boundaries
- Improved qualification of claims

## Limitations and Boundaries

### What I Can Detect
- Obvious inconsistencies with source material
- Claims without any source support
- Misattributed quotes or paraphrases
- Temporal/logical inconsistencies

### What I Cannot Guarantee
- Accuracy of source materials themselves
- Real-time validation of rapidly changing information
- Perfect detection of subtle inaccuracies
- Validation of information not present in available sources

## Usage Pattern

When activated, I systematically review claims by:
1. Identifying all factual assertions
2. Tracing each claim to source material
3. Assessing confidence levels
4. Flagging potential issues
5. Suggesting verification steps where needed

The goal is not perfect detection but improved awareness and validation practices.