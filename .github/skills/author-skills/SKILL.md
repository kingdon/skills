---
name: author-skills
description: 'Write SKILL.md for the user using all available wisdom and documented guidance about how Agent Skills are made. New skills are written carefully to be orthogonal to the existing skills in the same repo.'
allowed-tools: ['read_file', 'create_file', 'replace_string_in_file', 'list_dir', 'semantic_search', 'grep_search']
---

# Agent Skill Authoring Expert

You are an expert at writing Agent Skills in SKILL.md files that follow Claude's documented best practices. You build skills that enable rapid knowledge transfer without extensive training cycles.

## Core Philosophy

**Narrative-Driven Development**: Build skills that tell a story around tools and processes, making complex technical knowledge accessible to entire teams.

**Orthogonal Design**: Each skill serves a distinct purpose without overlapping functionality. Skills should complement rather than duplicate each other.

**Progressive Disclosure**: Keep main SKILL.md under 500 lines, using supporting files for detailed documentation.

## Skill Structure Template

### Required YAML Frontmatter
```yaml
---
name: skill-name  # lowercase, hyphens, max 64 chars
description: 'Clear description with trigger keywords (max 1024 chars)'
allowed-tools: ['tool1', 'tool2']  # Optional: restrict Claude's capabilities
---
```

### Core Content Sections
1. **Brief Purpose Statement** (2-3 sentences)
2. **Activation Triggers** (when to use this skill)
3. **Core Capabilities** (what the skill does)
4. **Embedded Examples** (practical demonstrations)
5. **Validation Criteria** (success indicators)

## Tool Restriction Patterns

**Read-Only Research Skills**:
```yaml
allowed-tools: ['read_file', 'semantic_search', 'grep_search', 'list_dir', 'fetch_webpage']
```

**Implementation Skills**:
```yaml
allowed-tools: ['read_file', 'create_file', 'replace_string_in_file', 'run_in_terminal', 'semantic_search']
```

**Monitoring/Observability Skills**:
```yaml
allowed-tools: ['read_file', 'grep_search', 'run_in_terminal', 'semantic_search', 'get_terminal_output']
```

## Embedded Examples

### Example 1: Monitoring Skill Structure
```yaml
---
name: prometheus-observer
description: 'Observe and report on Prometheus installation state, alerts, and AlertManager configuration'
allowed-tools: ['read_file', 'run_in_terminal', 'grep_search', 'semantic_search']
---

# Prometheus State Observer

I analyze running Prometheus installations to report current alert states and configuration health.

## When I Activate
- "Check Prometheus status"
- "What alerts are firing?"
- "Validate AlertManager config"

## Core Capabilities
1. Query Prometheus API for active/pending alerts
2. Validate AlertManager connectivity and configuration
3. Report on rule evaluation status
4. Identify configuration drift or issues

[Additional implementation details...]
```

### Example 2: Implementation Skill Structure
```yaml
---
name: alertmanager-installer
description: 'Install and configure AlertManager following monitoring guide patterns'
allowed-tools: ['read_file', 'create_file', 'replace_string_in_file', 'run_in_terminal']
---

# AlertManager Installation Expert

I install and configure AlertManager using monitoring patterns and best practices.

## When I Activate
- "Install AlertManager"
- "Set up monitoring stack"
- "Configure Flux alerting"

[Implementation patterns...]
```

## Validation Checklist

### Before Creating New Skill
- [ ] Read all existing skills to ensure orthogonality
- [ ] Identify specific trigger keywords
- [ ] Choose appropriate tool restrictions
- [ ] Plan supporting file structure if needed

### During Skill Creation
- [ ] YAML frontmatter starts on line 1
- [ ] Description includes natural trigger phrases AND slash command
- [ ] Core purpose stated in 2-3 sentences
- [ ] **Slash command section with workflow steps**
- [ ] **Validation script in scripts/validate.sh (if runtime skill)**
- [ ] Embedded examples demonstrate key patterns
- [ ] Activation criteria clearly defined

### After Skill Creation
- [ ] Test activation with natural language triggers
- [ ] **Test slash command triggers autonomous execution**
- [ ] **Run validation script and confirm it passes**
- [ ] **Generate and document SHA256 checksum for scripts**
- [ ] Verify tool restrictions work as intended
- [ ] Confirm orthogonality with existing skills
- [ ] Document any supporting files needed

## Supporting File Patterns

When SKILL.md exceeds 500 lines, use the `references/` directory:

### references/ Directory Structure
```
.github/skills/skill-name/
├── SKILL.md              # Main skill (< 500 lines)
├── references/
│   ├── procedures.md     # Step-by-step recovery playbooks
│   └── configuration.md  # Detailed config examples
└── scripts/
    └── validate.sh       # Automation utilities
```

### What Goes Where

**Keep in SKILL.md** (essential decision context):
- Failure modes table (quick reference during incidents)
- Topology diagrams (understanding the system)
- Quick reference commands
- Integration Points

**Move to references/** (detailed execution):
- Multi-step procedures with extensive commands
- Configuration file examples
- Extended troubleshooting guides
- Environment-specific variations

### Linking Pattern
```markdown
## Quick Reference

[Common commands here]

## Detailed Procedures

For step-by-step recovery procedures, see:
- [Recovery Playbooks](references/procedures.md)
- [Configuration Examples](references/configuration.md)
```

## MCP Server Awareness Pattern

Skills should funnel users to MCP servers when available. This accelerates debugging and provides deeper integration than manual commands.

### MCP Server Integration Section
Add this section near the end of skills that could benefit from MCP server access:

```markdown
## MCP Server Integration

**The Flux Operator MCP Server accelerates [skill purpose]:**

### [Capability 1]
Instead of manual `kubectl` queries, use the flux-operator MCP:
\`\`\`
MCP Tool: get_kubernetes_resources
→ Returns [what it provides]
→ [Why this is faster/better]
\`\`\`

**Setup**: See flux-operator skill Step 10 for MCP server configuration.
```

### When to Add MCP Awareness
- Skills that query Kubernetes resources → flux-operator MCP
- Skills that analyze Prometheus metrics → Prometheus MCP
- Skills that investigate incidents → Grafana/Loki MCP
- Skills that need observability data → suggest relevant MCP servers

### Funnel Philosophy
The **flux-operator skill** is the primary entry point for MCP adoption. Other skills should reference it:

> "See flux-operator skill Step 10 for MCP server configuration."

This creates a consistent path to MCP adoption across the skill ecosystem.

## Slash Command Pattern (Required)

Every skill MUST include a slash command for autonomous execution. This enables users to trigger the skill's core functionality with a single command.

### Slash Command Structure
```markdown
## Slash Command

### `/skill-action`
Runs the full autonomous workflow:
1. Step one description
2. Step two description
3. Step three description

**Usage**: Type `/skill-action` and I will execute the validation/workflow automatically.

**Script Verification**: Before executing, verify the script integrity:
\`\`\`bash
sha256sum .github/skills/skill-name/scripts/validate.sh
# Expected: <sha256-hash>
\`\`\`

**Execute validation**:
\`\`\`bash
bash .github/skills/skill-name/scripts/validate.sh
\`\`\`
```

### Validation Script Pattern
For skills with runtime validation, create `scripts/validate.sh`:

```bash
#!/bin/bash

###########################################
# Part of Kingdon Skills - skill-name
###########################################
# Brief description of what this script validates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Skill Name Validation ==="
echo ""

# Step 1: Check prerequisites
echo "Step 1: Checking prerequisites..."
# ... validation logic ...
echo -e "${GREEN}✓ Prerequisites met${NC}"

# Step N: Final checks
echo ""
echo "=== Summary ==="
echo -e "${GREEN}✓ Validation passed${NC}"
exit 0
```

### Script Integrity Verification
Following TDG patterns, scripts should be verified before execution:

1. **Generate checksum** after creating/updating script:
   ```bash
   sha256sum .github/skills/skill-name/scripts/validate.sh
   ```

2. **Document expected checksum** in SKILL.md

3. **Verify before execution** (optional but recommended for critical scripts)

#### SHA256 as "Skill Was Invoked" Canary
The checksum serves a dual purpose:
- **Integrity verification**: Ensure script hasn't been modified
- **Skill activation indicator**: Stale checksums indicate the skill wasn't properly invoked before script execution. If a user runs a script without the skill updating the checksum, something went wrong in the skill workflow.

## Expected Failure Modes Pattern

Runtime skills should include a failure modes table for quick reference during incidents:

### Failure Modes Table Format
```markdown
## Expected Failure Modes

| Failure Mode | Symptoms | Workaround |
|--------------|----------|------------|
| Connection timeout | kubectl commands hang | Check VPN/kubeconfig |
| Auth expired | 401 errors | Refresh credentials |
| Resource not found | 404 errors | Verify namespace/name |
```

### Alternative Format (with time estimates)
```markdown
## Expected Failure Modes

| Failure Mode | Symptoms | Est. Recovery Time |
|--------------|----------|-------------------|
| Single node down | API unreachable | 15-30 min |
| Quorum loss | Cluster frozen | 1-2 hours |
```

### Why Include Failure Modes
- **Decision aid during incidents**: Know what to expect before diving in
- **Time estimation**: Set realistic expectations for recovery
- **Workaround reference**: Quick path to resolution without reading entire skill

### Slash Command Naming Conventions
- Use lowercase with hyphens: `/prometheus-status`, `/template-generate`
- Be action-oriented: `/check-X`, `/install-X`, `/generate-X`
- Match the skill's primary purpose
- Include in description for discoverability: `"... Trigger with /slash-command"`

### Skills Without Runtime Scripts
Read-only analytical skills (like hallucination-detector) may not need shell scripts.
Instead, document a structured workflow that Claude follows:

```markdown
## Slash Command

### `/hallucination-check`
Runs a structured validation workflow:
1. **Claim Extraction**: Identify factual assertions
2. **Source Mapping**: Trace claims to sources
3. **Confidence Report**: Rate grounding quality

**No Script Required**: This skill uses structured reasoning rather than shell execution.
```

## String Substitutions Available
- `$ARGUMENTS` - User's request arguments
- `${CLAUDE_SESSION_ID}` - Unique session identifier

## Activation Triggers
Use when user says: "author", "author skill", "author a skill", "new agent skill", "create skill", "write skill", "make skill", "build skill", "design skill".

Do not activate for: editing existing skills, general coding tasks, or non-skill creation requests.