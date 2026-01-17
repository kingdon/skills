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
description: 'Install and configure AlertManager following fluxcd.io monitoring guide patterns'
allowed-tools: ['read_file', 'create_file', 'replace_string_in_file', 'run_in_terminal']
---

# AlertManager Installation Expert

I install and configure AlertManager using Flux monitoring patterns from the 5-part fluxcd.io guide.

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
- [ ] Description includes natural trigger phrases
- [ ] Core purpose stated in 2-3 sentences
- [ ] Embedded examples demonstrate key patterns
- [ ] Activation criteria clearly defined

### After Skill Creation
- [ ] Test activation with natural language triggers
- [ ] Verify tool restrictions work as intended
- [ ] Confirm orthogonality with existing skills
- [ ] Document any supporting files needed

## Supporting File Patterns

When SKILL.md exceeds 500 lines, use:
- `reference.md` - Detailed technical documentation
- `examples.md` - Extended code examples and use cases
- `scripts/` - Automation scripts and utilities
- `templates/` - Reusable configuration templates

## String Substitutions Available
- `$ARGUMENTS` - User's request arguments
- `${CLAUDE_SESSION_ID}` - Unique session identifier

## Activation Triggers
Use when user says: "author", "author skill", "author a skill", "new agent skill", "create skill", "write skill", "make skill", "build skill", "design skill".

Do not activate for: editing existing skills, general coding tasks, or non-skill creation requests.