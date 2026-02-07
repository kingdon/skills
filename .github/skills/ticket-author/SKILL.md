---
name: ticket-author
description: 'Author work tickets in standard format with Business Value, Requirements, Deliverables, and Notes sections. Supports Jira, GitHub Issues, GitLab Issues. Trigger with /ticket or "write a ticket"'
allowed-tools: ['read_file', 'semantic_search', 'grep_search', 'list_dir']
---

# Ticket Author

I write work tickets in a structured format ensuring consistent structure and appropriate level of detail for agile workflows. I support multiple output formats: Jira wiki markup, GitHub Markdown, GitLab Markdown, or plain todo items.

## Slash Command

### `/ticket`
Generates a properly formatted ticket based on context:
1. **Context Gathering**: Understand the work item from conversation or provided details
2. **Business Value Synthesis**: Articulate why this matters to the organization
3. **Requirements Extraction**: Identify prerequisites and acceptance criteria
4. **Deliverables Definition**: List tangible outputs without over-specifying
5. **Notes Addition**: Include relevant technical details or context

**Usage**: Type `/ticket` followed by a description of the work, or use after discussing a topic to generate a ticket from context.

**Format Selection**: Add format hint or I'll default to Jira:
- `/ticket --github ...` or "as a GitHub issue"
- `/ticket --gitlab ...` or "as a GitLab issue"  
- `/ticket --jira ...` or "in Jira format"
- `/ticket --todo ...` or "as a todo item"

**Example**:
```
/ticket Update the backup job to use the new GitOps repos and fix the deprecated registry reference
```

**No Script Required**: This is a content generation skill that produces formatted text.

## When I Activate
- `/ticket` (slash command)
- "write a ticket"
- "create a ticket for"
- "author a story for"
- "format this as a ticket"
- "as a GitHub issue"
- "in Jira format"
- "GitLab issue"

## Output Formats

### Jira Format (Default)
Uses Jira wiki markup syntax (`*` bullets, `{code}` blocks).

### GitHub Issue Format
Uses GitHub Flavored Markdown with task lists, labels hint, and clean formatting.

### GitLab Issue Format
Uses GitLab Markdown with `/label` quick actions and weight hints.

### Plain Todo Format
Simple markdown checklist for personal task tracking.

---

## Ticket Template (Jira)

```
*Summary*
A concise title for the ticket (one line, action-oriented). This IS the ticket title in Jira.

*Business Value*
A sentence or two about how this relates to priorities and why we need to do it, from a business perspective. Don't go into too much detail.

*Requirements*
* A bulleted list
* These are either required elements before we can do the work, or required features of the deliverables
** They can have sub-requirements
*** And those can have sub-requirements
* A bulleted list of requirements

*Deliverables*
* A list of assets that are expected to be delivered as a result of this story/task's completion
* These are tangible files or documents that we should have produced & logged when the ticket is marked done
* Try to be specific, but do not over-specify (Agile principle: detailed specs increase risk at capacity)

*Notes*
Free-form section for additional context, technical details, or implementation hints.
This section is not required, and may be omitted entirely. Other headings than "Notes"
may also be used, when a more structured narrative is required to convey the details.
```

## Ticket Template (GitHub Issue)

```markdown
## Summary
Brief description of what needs to be done.

## Business Value
Why this matters to the project/organization.

## Requirements
- [ ] Prerequisite or acceptance criterion
- [ ] Another requirement
  - [ ] Sub-requirement if needed

## Deliverables
- [ ] Tangible output 1
- [ ] Tangible output 2

## Notes
Additional context, technical details, or implementation hints.

---
**Labels**: `enhancement`, `priority:medium`
```

## Ticket Template (GitLab Issue)

```markdown
## Summary
Brief description of what needs to be done.

## Business Value
Why this matters to the project/organization.

## Requirements
- [ ] Prerequisite or acceptance criterion
- [ ] Another requirement

## Deliverables
- [ ] Tangible output 1
- [ ] Tangible output 2

## Notes
Additional context.

/label ~enhancement ~"priority::medium"
/weight 3
```

## Ticket Template (Plain Todo)

```markdown
## [Task Title]

**Why**: One sentence on business value

**Requirements**:
- [ ] Requirement 1
- [ ] Requirement 2

**Done when**:
- [ ] Deliverable 1
- [ ] Deliverable 2
```

---

## Formatting Rules

### Summary Section (Title)
- **Critical**: Summary IS the ticket title
- **Length**: One line, typically 5-12 words
- **Format**: Action-oriented, starts with verb or noun
- **Style**: Sentence case, no trailing punctuation
- **Examples**: "Update backup job to use new GitOps repos", "Fix deprecated registry references in workflows"

### Business Value Section
- **Length**: 1-3 sentences maximum
- **Audience**: Executives and managers, not implementers
- **Perspective**: Business/organizational impact, not technical details
- **Tone**: Concise, outcome-focused, high-level
- **Avoid**: Implementation details, technical jargon, lengthy justifications

### Requirements Section
- **Format**: Platform-appropriate bullets (Jira: `*`, GitHub/GitLab: `- [ ]`)
- **Content**: Prerequisites OR acceptance criteria (can be both)
- **Granularity**: Specific enough to verify, general enough to allow flexibility
- **Nesting**: Use sub-bullets for related items, max 3 levels deep

### Deliverables Section
- **Format**: Platform-appropriate bullets
- **Content**: Tangible outputs that can be linked in comments or PR
- **Examples**: Files, documents, configurations, deployed resources
- **Principle**: Less is more - over-specification increases delivery risk

### Notes Section
- **Format**: Free-form, can include code blocks, links, diagrams
- **Content**: Context that helps the implementer but isn't a requirement
- **Optional**: Only include if genuinely helpful

## Quality Checklist

Before outputting a ticket, verify:
- [ ] Summary is concise, action-oriented, one line
- [ ] Business Value is 1-3 sentences, business-focused
- [ ] Requirements use proper platform syntax
- [ ] Deliverables are tangible and verifiable
- [ ] No over-specification that increases risk
- [ ] Notes add value without duplicating other sections

## Examples

### Example 1: Infrastructure Task (Jira)
```
*Summary*
Migrate backup job to new GitOps repos

*Business Value*
Ensure operational continuity by migrating backup jobs to the new GitOps infrastructure before the legacy system is decommissioned.

*Requirements*
* New GitOps repos must be accessible
* Container image must be available in target registry
* IAM role permissions must allow S3 write access to backup bucket

*Deliverables*
* Updated claim with new containerImage reference
* Updated gitUrl pointing to new repo(s)
* Verification that backup job runs successfully
```

### Example 2: Feature Story (GitHub)
```markdown
## Summary
Create Backstage template for self-service EKS cluster provisioning

## Business Value
Enable self-service cluster provisioning for teams, reducing ops toil and accelerating project onboarding.

## Requirements
- [ ] Backstage catalog deployed and accessible
- [ ] ProviderConfig for target AWS accounts exists
- [ ] RBAC allows team leads to create claims

## Deliverables
- [ ] Backstage template for EKS cluster provisioning
- [ ] Documentation for template usage
- [ ] At least one successful test cluster creation

## Notes
Consider starting with a minimal template that creates only the cluster, then iterating to add Karpenter, addons, etc. as optional components.

---
**Labels**: `enhancement`, `backstage`, `self-service`
```

### Example 3: Bug Fix (GitLab)
```markdown
## Summary
Fix AlertManager routing after Prometheus upgrade

## Business Value
Restore monitoring visibility by fixing alert routing that broke after the Prometheus upgrade.

## Requirements
- [ ] Access to the monitoring namespace
- [ ] AlertManager configuration backed up before changes

## Deliverables
- [ ] Fixed alertmanager-config.yaml
- [ ] Verified alerts routing to correct channel

## Notes
The issue started after upgrading kube-prometheus-stack to v45.x. Check the breaking changes in the release notes.

/label ~bug ~monitoring ~"priority::high"
/weight 2
```

## Anti-Patterns to Avoid

### ❌ Over-Detailed Business Value
```
We need to update the backup job because the old registry is being deprecated and all images need to move to the new registry, and this is part of the larger initiative to adopt resources from the other team...
```
**Why bad**: Too much detail, mixes business and technical concerns.

### ❌ Vague Requirements
```
* Make it work
* Test it
```
**Why bad**: Not verifiable, doesn't help implementer.

### ❌ Over-Specified Deliverables
```
* Update line 47 of claim.yaml to change containerImage from X to Y
* Update line 52 to change gitUrl from A to B
* Run kubectl apply -f claim.yaml
* Run kubectl get cronjob -n namespace
* Verify output shows...
```
**Why bad**: Too prescriptive, becomes outdated, removes implementer judgment.

### ❌ Wrong Bullet Format
```
*Requirements*
- This uses markdown bullets
- Jira won't render these correctly
```
**Why bad**: Use `*` for Jira wiki markup, not `-`. Match the platform.
