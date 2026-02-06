```skill
---
name: postmortem-author
description: 'Generate Sunkworks-style post-mortem reports with timeline reconstruction, failure pattern recognition, honest technical assessments, and recovery playbooks. Trigger with /postmortem'
allowed-tools: ['read_file', 'create_file', 'replace_string_in_file', 'run_in_terminal', 'grep_search', 'semantic_search', 'get_terminal_output']
tags: ['sunkworks', 'live-stream', 'failure-tolerant']
---

# Post-Mortem Author

**"Every failure is a future blog post."**

I generate Sunkworks-style post-mortem reports that embrace the honest, educational nature of live troubleshooting. These reports acknowledge what went wrong, document the iterative debugging process, and create actionable recovery playbooks.

**Philosophy**: Unlike corporate blameless post-mortems that often sanitize reality, Sunkworks post-mortems celebrate the messy truth of debugging live systems. We document the wrong turns, the red herrings, and the "oh, it was THAT the whole time" moments.

## Slash Command

### `/postmortem`
Generates a post-mortem report:
1. Collect Kubernetes events from the incident window
2. Analyze Terraform state history for infrastructure changes
3. Identify failure patterns from previous incidents
4. Generate structured report with timeline and recovery steps

**Usage**: Type `/postmortem` after an incident to generate the report.

**Arguments**: 
- `/postmortem <hours-ago>` - Analyze last N hours (default: 4)
- `/postmortem <start-time> <end-time>` - Specific time window

**Script Verification**: Before executing, verify the script integrity:
```bash
sha256sum .github/skills/postmortem-author/scripts/collect-timeline.sh
# Expected: 9fa5f345e459dd8c05337d0ff2d026f2d3e588c3169c42a01c7ffc0a5c1b0528
```

**Execute timeline collection**:
```bash
bash .github/skills/postmortem-author/scripts/collect-timeline.sh
```

## When I Activate
- `/postmortem` (slash command)
- "Generate post-mortem"
- "Write incident report"
- "What went wrong"
- "Document the failure"
- "Create recovery playbook"
- "Episode notes"
- "Analyze the outage"

## Expected Failure Modes

### Data Collection Failures
| Failure Mode | Symptoms | Workaround |
|--------------|----------|------------|
| Events pruned | Kubernetes events older than 1hr missing | Check etcd, use Prometheus metrics |
| Terraform state locked | Cannot read state history | Use `terraform force-unlock` or read state file directly |
| Logs rotated | Container logs unavailable | Check persistent log storage, Loki if available |
| Time sync drift | Event timestamps don't correlate | Document clock skew, use relative ordering |

### Analysis Failures
| Failure Mode | Symptoms | Est. Impact |
|--------------|----------|-------------|
| Incomplete timeline | Gaps in event sequence | May miss root cause |
| False pattern match | Similarity to previous incident misleads | Add "false alarm" to pattern database |
| Missing context | Key decisions undocumented during incident | Interview participants, check stream VOD |

## Post-Mortem Template

### Standard Sunkworks Format

```markdown
# Post-Mortem: [Incident Title]

**Date**: YYYY-MM-DD
**Duration**: X hours Y minutes
**Severity**: [CRITICAL|HIGH|MEDIUM|LOW]
**Episode**: Sunkworks #NN (if applicable)

## TL;DR
One paragraph summary. What broke, how we fixed it, what we learned.

## Timeline

| Time (UTC) | Event | Source |
|------------|-------|--------|
| HH:MM | First symptom observed | Prometheus alert |
| HH:MM | Investigation started | Stream timestamp |
| HH:MM | Root cause identified | kubectl describe |
| HH:MM | Fix applied | git commit SHA |
| HH:MM | Service restored | Flux reconciliation |

## What Went Wrong

### Root Cause
Technical explanation of the failure. Be specific.

### Contributing Factors
- Factor 1: Why this made things worse
- Factor 2: Why detection was delayed
- Factor 3: Why recovery took longer than expected

### Red Herrings
Things we investigated that weren't the problem:
- Thing 1: Why we thought it was this, why it wasn't
- Thing 2: The suspicious timing that was coincidental

## The Debugging Journey

### Attempt 1: [What We Tried]
**Hypothesis**: What we thought was wrong
**Action**: What we did
**Result**: What happened
**Time Spent**: X minutes

### Attempt 2: [What We Tried Next]
**Hypothesis**: Refined theory
**Action**: Different approach
**Result**: Getting warmer / still wrong
**Time Spent**: X minutes

### The Breakthrough
What finally led us to the answer. Often: "Then we noticed..."

## Recovery Steps

1. Step one (include exact commands)
2. Step two
3. Step three
4. Verification that it worked

## Failure Pattern Analysis

### Have We Seen This Before?
- Episode N: Similar symptoms, different cause
- Episode M: Same root cause, different symptoms

### Pattern Category
[NEW PATTERN | KNOWN VARIANT | RECURRENCE]

### Pattern Triggers
What conditions led to this failure:
- Trigger 1
- Trigger 2

## Prevention & Detection

### Immediate Actions (This Week)
- [ ] Action 1: Owner: @name
- [ ] Action 2: Owner: @name

### Long-term Improvements
- [ ] Improvement 1: Target date
- [ ] Improvement 2: Target date

### New Alerts/Monitors
- Alert 1: What it detects
- Alert 2: Earlier warning for this failure mode

## Metrics

- **Time to Detect (TTD)**: X minutes from failure to first alert
- **Time to Understand (TTU)**: X minutes from alert to root cause
- **Time to Recover (TTR)**: X minutes from root cause to resolution
- **Total Downtime**: X hours Y minutes

## The Honest Assessment

### What We Did Well
- Thing 1
- Thing 2

### What We Could Have Done Better
- Thing 1: How it would have helped
- Thing 2: Why we didn't do it

### The Lesson
One key takeaway from this incident.

## Recovery Playbook

For future occurrences of this failure pattern:

\`\`\`bash
# Step 1: Verify the failure mode
command to check

# Step 2: Apply the fix
command to fix

# Step 3: Verify recovery
command to verify
\`\`\`

Estimated recovery time: X minutes (if you follow this playbook)
```

## Core Capabilities

### 1. Timeline Reconstruction

```bash
# Collect Kubernetes events from last 4 hours
kubectl get events -A --sort-by=.lastTimestamp | \
  awk -v cutoff="$(date -u -d '4 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
  '$1 >= cutoff {print}'

# Get Flux reconciliation history
kubectl get kustomization -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.lastAttemptedRevision}{"\t"}{.status.conditions[-1].lastTransitionTime}{"\n"}{end}'

# Check HelmRelease history
kubectl get helmrelease -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.lastAttemptedRevision}{"\t"}{.status.conditions[-1].lastTransitionTime}{"\n"}{end}'
```

### 2. Terraform State Analysis

```bash
# List Terraform state history (S3/GCS backend)
terraform state list

# Show specific resource history
terraform show -json | jq '.values.root_module.resources[] | select(.address == "<resource>")'

# Compare states (if using versioned backend)
terraform state pull > current-state.json
# Download previous version from backend and compare
diff <(jq -S . previous-state.json) <(jq -S . current-state.json)
```

### 3. Failure Pattern Recognition

Query the pattern database for similar incidents:

```bash
# Search for similar symptoms in previous post-mortems
grep -r "etcd" docs/postmortems/*.md
grep -r "quorum" docs/postmortems/*.md

# Find incidents with same affected components
grep -l "helm-controller" docs/postmortems/*.md
```

#### Known Sunkworks Failure Patterns

| Pattern ID | Name | Key Symptoms | Episodes |
|------------|------|--------------|----------|
| PM-001 | Tailscale Extension Hang | Node NotReady, network init timeout | #3, #7 |
| PM-002 | etcd Disk Pressure | Leader election failures, slow API | #5 |
| PM-003 | HelmRelease Timeout | Chart fetch succeeds, install hangs | #2, #4 |
| PM-004 | Synology NFS Stale | Pods stuck ContainerCreating on mount | #6 |
| PM-005 | DNS Resolution Loop | CoreDNS->PiHole->CoreDNS cycle | #8 |

### 4. "What Went Wrong" Generator

Structured analysis prompts:

```markdown
## Analysis Framework

### The Failure
What specifically stopped working? Be precise:
- Service X returned errors
- Pods could not schedule
- Network connectivity lost between A and B

### The Trigger
What change or event preceded the failure?
- Deployment of version X
- Certificate expiration
- Upstream dependency failure
- "Nothing changed" (always investigate this claim)

### The Amplifier
What made this worse than it could have been?
- Retry storms
- Cascading failures
- Missing alerts
- Documentation gaps

### The Discovery
How was the problem found?
- User report
- Monitoring alert
- Manual observation
- Flux reconciliation failure
```

## Recovery Playbooks

### Generate Playbook From Incident

After resolving an incident, extract the recovery steps:

```bash
#!/bin/bash
# generate-playbook.sh

echo "# Recovery Playbook: $1"
echo ""
echo "## Symptoms"
echo "- Symptom 1"
echo "- Symptom 2"
echo ""
echo "## Prerequisites"
echo "- Access to cluster"
echo "- kubectl configured"
echo ""
echo "## Steps"
echo ""
echo "### Step 1: Verify Failure Mode"
echo "\`\`\`bash"
echo "# Command to confirm this is the right playbook"
echo "\`\`\`"
echo ""
echo "### Step 2: Apply Fix"
echo "\`\`\`bash"
echo "# Commands from the successful recovery"
echo "\`\`\`"
echo ""
echo "### Step 3: Verify"
echo "\`\`\`bash"
echo "# Commands to confirm recovery"
echo "\`\`\`"
echo ""
echo "## Estimated Time: X minutes"
echo ""
echo "## Related Incidents"
echo "- [Incident Title](./incident-file.md)"
```

## Integration Points

- **SOS Emergency**: Use after `/sos` recovery to document what happened
- **Flux Operator**: Pull GitOps event history for timeline
- **Prometheus Observer**: Include alert firing/resolution times

## Episode Time Estimates

### Post-Mortem Writing Time (by complexity)

| Incident Type | Data Collection | Analysis | Writing | Total |
|--------------|-----------------|----------|---------|-------|
| Simple (one component) | 10 min | 15 min | 20 min | 45 min |
| Medium (multi-component) | 20 min | 30 min | 30 min | 1.5 hr |
| Complex (cascading failure) | 30 min | 45 min | 45 min | 2 hr |
| Epic (everything broke) | 45 min | 1 hr | 1 hr | 2.5 hr |

## Sunkworks Episode Notes

*"The audience learns more from our failures than our successes. Document both."*

### Capturing Live Debug Context
During stream incidents, capture:
- Stream timestamp when symptom first noticed
- Chat suggestions that were tried
- The moment of realization (for the highlight reel)
- What the "fix" actually was vs. what chat thought it was
```
