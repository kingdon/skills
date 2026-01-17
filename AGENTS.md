# AGENTS.md

## Project Overview
Kingdon Skills provides Claude Agent Skills for rapid deployment of Kubernetes monitoring expertise. Built to enable teams to effectively operate Flux + Crossplane environments with Prometheus and AlertManager without extensive training cycles.

## Skills Architecture
- Location: `.github/skills/` (git-distributed, team-wide)
- Pattern: Progressive disclosure with SKILL.md + supporting files
- Philosophy: Narrative-driven, orthogonal, rapid deployment

## Development Commands

### Skill Validation
```bash
# Check all skills are properly structured
find .github/skills -name "SKILL.md" -exec head -10 {} \;

# Validate YAML frontmatter
grep -r "^---$" .github/skills/*/SKILL.md

# Check for tool restrictions
grep -r "allowed-tools:" .github/skills/
```

### Testing Skills
```bash
# Test skill activation triggers
# Use natural language to validate each skill activates correctly:
# - "Check Prometheus status" → prometheus-observer
# - "Install AlertManager" → alertmanager-installer  
# - "Adapt metrics for Crossplane" → ksm-crossplane-adapter
```

## Code Style
- YAML frontmatter must start on line 1
- Skill names: lowercase, hyphens, max 64 chars
- Descriptions: include natural trigger phrases
- Progressive disclosure: main SKILL.md under 500 lines
- Supporting files: reference.md, examples.md, scripts/, templates/

## Skill Categories

### Read-Only Research Skills
```yaml
allowed-tools: ['read_file', 'semantic_search', 'grep_search', 'list_dir', 'fetch_webpage']
```
Use for: prometheus-observer, hallucination-detector

### Implementation Skills  
```yaml
allowed-tools: ['read_file', 'create_file', 'replace_string_in_file', 'run_in_terminal', 'semantic_search']
```
Use for: alertmanager-installer, resource-template-engine

### Monitoring/Observability Skills
```yaml
allowed-tools: ['read_file', 'grep_search', 'run_in_terminal', 'semantic_search', 'get_terminal_output']  
```
Use for: ksm-crossplane-adapter

### Meta Skills
```yaml
allowed-tools: ['read_file', 'create_file', 'replace_string_in_file', 'list_dir', 'semantic_search', 'grep_search']
```
Use for: author-skills

## Orthogonality Requirements
- Each skill serves distinct purpose without overlap
- Use semantic search to validate new skills don't duplicate existing functionality
- Author Skills provides validation checklist for new skill creation

## Activation Testing
After skill changes, reload editor and test with natural phrases:
- Research: "What's the current state of..."
- Implementation: "Install..." or "Configure..."  
- Analysis: "Check..." or "Validate..."
- Meta: "Author..." or "Create skill..."

## Security Considerations
- Tool restrictions limit Claude capabilities per skill type
- No credential exposure in skill examples
- Read-only skills cannot modify infrastructure
- Implementation skills restricted to specific tool sets

## Supporting File Structure
```
.github/skills/skill-name/
├── SKILL.md              # Main skill (< 500 lines)
├── reference.md          # Detailed documentation  
├── examples.md           # Extended examples
└── scripts/              # Automation utilities
```

## Validation Commands
```bash
# Check skill naming conventions
ls -la .github/skills/ | grep -E '^[a-z-]+$'

# Verify frontmatter format
head -5 .github/skills/*/SKILL.md | grep -E '^(---|name:|description:)'

# Test progressive disclosure limits
wc -l .github/skills/*/SKILL.md | sort -n
```