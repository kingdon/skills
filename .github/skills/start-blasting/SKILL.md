---
name: start-blasting
description: 'Pragmatic task execution that chooses the fastest path: script it, LLM it, or just do it. For mundane tasks humans are slow at but LLMs blast through. Trigger with /blast or /fast-path or "just do it"'
allowed-tools: ['read_file', 'create_file', 'replace_string_in_file', 'run_in_terminal', 'semantic_search', 'grep_search', 'list_dir', 'get_terminal_output', 'fetch_webpage']
---

# Start Blasting 🔫

**Pragmatic task execution for mundane, repetitive work that humans shouldn't spend brain cycles on.**

*"So anyway, I started blasting."* - The philosophy: Why script it if the LLM can just do it? Why use an LLM if a script works? But also - why build a script that won't work when the LLM can blast right past it?

## Slash Commands

### `/blast`
Start executing a task pragmatically - choose fastest path to done.

### `/fast-path`
Alias for `/blast` - same functionality, SFW name.

## Core Principle

**Choose the fastest path to done:**

1. **Can I just do it?** → Do it (no meta-work needed)
2. **Is there a pattern worth capturing?** → Note it, but finish first
3. **Will this recur often enough to script?** → Script it after proving the pattern
4. **Is the script breaking?** → LLM brainpower bypasses broken tooling
5. **Is there an MCP server for this?** → Use it (structured tool access beats parsing)

**The trap to avoid**: Getting bogged down building automation for a one-time task, or manually grinding through something the LLM handles in seconds.

## When I Activate

- `/blast` or `/fast-path` (slash commands)
- "Just do it" / "start blasting" / "blast through this"
- "Compare these and tell me what's different"
- "Filter out the noise"
- "Help me get through this tedious task"
- "Check all of these for X"
- Repetitive file operations, comparisons, audits
- Tasks where human attention is the bottleneck

## The Decision Tree

```
┌─────────────────────────────────────────────────────────────┐
│                    NEW TASK ARRIVES                         │
└─────────────────────┬───────────────────────────────────────┘
                      ▼
              ┌───────────────┐
              │ Is it trivial │──Yes──▶ JUST DO IT
              │ (< 2 min)?    │         (no meta-work)
              └───────┬───────┘
                      │ No
                      ▼
              ┌───────────────┐
              │ MCP server    │──Yes──▶ USE MCP TOOLS
              │ available?    │         (structured > parsing)
              └───────┬───────┘
                      │ No
                      ▼
              ┌───────────────┐
              │ Can LLM blast │──Yes──▶ LLM DOES IT
              │ through it?   │         (parallel reads, fast reasoning)
              └───────┬───────┘
                      │ No (needs iteration, external state)
                      ▼
              ┌───────────────┐
              │ Existing      │──Yes──▶ RUN THE SCRIPT
              │ script works? │         (trust automation)
              └───────┬───────┘
                      │ No
                      ▼
              ┌───────────────┐
              │ Script fixable│──Yes──▶ FIX IT (if < 5 min)
              │ quickly?      │         otherwise LLM bypass
              └───────┬───────┘
                      │ No
                      ▼
              ┌───────────────┐
              │ Worth scripting│──Yes──▶ BUILD SCRIPT
              │ for future?   │          (capture the pattern)
              └───────┬───────┘
                      │ No
                      ▼
                 LLM JUST DOES IT
                 (one-time execution)
```

## MCP Server Awareness

When available, prefer MCP servers over terminal commands:

| Domain | MCP Server | Why Use It |
|--------|-----------|------------|
| Flux/GitOps | `flux-operator` | Structured status, safe read-only queries |
| Kubernetes | MCP tools | Direct API access, no kubectl parsing |
| GitHub | GitHub MCP | Structured PR/issue creation |
| Databases | DB-specific MCP | Query without SQL injection risk |

**MCP benefits**:
- Structured responses (no parsing fragile CLI output)
- Built-in safety boundaries
- Consistent error handling
- Tool-specific context

## Execution Patterns

### Pattern 1: Bulk Comparison (Fork Reconciliation)

**Scenario**: You have copies/forks that might have drifted.

**LLM Approach** (usually fastest):
```bash
# One command, immediate analysis
diff -urN original/ "original copy/" 2>/dev/null || echo "(missing)"
```

Then: LLM reads output, categorizes differences, surfaces decisions.

**Don't**: Write a Python script to parse diff output when eyeballs + LLM reasoning handles it in 10 seconds.

### Pattern 2: Batch File Operations

**Scenario**: Rename/move/delete many files based on criteria.

**Assess first**:
```bash
# See the scope
ls -la *\ copy/ 2>/dev/null | wc -l
```

**If small set**: Just do it inline
```bash
rm -r "identical-copy/" "another-identical/"
```

**If large/complex**: Build the command list, review, execute
```bash
# Generate commands, human reviews, then execute
for d in *\ copy; do echo "rm -r \"$d\""; done
```

### Pattern 3: Audit/Validation Sweeps

**Scenario**: Check many files for a condition.

**LLM parallel reads**: Read multiple files simultaneously, report findings.

**When to script**: If this exact check runs in CI or recurs weekly.

### Pattern 4: Noise Filtering

**Scenario**: Large output, need human-relevant subset.

**LLM strength**: Read the full output, extract what matters, present decisions.

**Example**: 500-line diff → "3 files identical (delete), 1 has meaningful changes (review), 2 copies have content original lacks (merge decision needed)"

### Pattern 5: MCP-First Kubernetes

**Scenario**: Need cluster state information.

**With MCP** (preferred):
```
# Use flux-operator MCP tools
get_kubernetes_resources(kind="Kustomization", namespace="flux-system")
```

**Without MCP** (fallback):
```bash
kubectl get kustomization -n flux-system -o json | jq '...'
```

## The Human Handoff

Always surface decisions that need human judgment:

```markdown
## Ready for Your Decision

### Safe to Delete (no differences)
- `alertmanager-installer copy/`
- `prometheus-observer copy/`

### Needs Review (has changes)
- `flux-operator copy/` - Original is newer, structured better
- `tdg copy/` - Original is EMPTY, copy has full content

### Recommended Actions
1. Delete identical copies: `rm -r "safe1/" "safe2/"`
2. Review diff for flux-operator (I can show you)
3. Move tdg copy to replace empty original?

**Your call on #2 and #3. Say "proceed" for safe deletions.**
```

## Anti-Patterns to Avoid

### ❌ Premature Scripting
Building automation before proving the task is worth automating.
```
Human: "Check if these 3 files have the same header"
Wrong: Write a Python script with argparse
Right: Read all 3, compare, answer in 20 seconds
```

### ❌ Script Worship
Fighting with broken tooling when brainpower solves it faster.
```
Wrong: Debug why jq isn't parsing this edge case
Right: LLM reads the JSON, extracts what you need
```

### ❌ Perfectionist Paralysis
Over-engineering a one-time task.
```
Wrong: "Let me create a reusable framework for diff analysis"
Right: Run diff, read output, summarize, done
```

### ❌ Missing the Capture Opportunity
Finishing without noting a useful pattern.
```
Wrong: Do the task, forget the pattern existed
Right: "This worked. Want me to author a skill for this pattern?"
```

### ❌ Ignoring Available MCP
Parsing CLI output when structured tools exist.
```
Wrong: kubectl get pods -o json | jq '.items[] | ...' (fragile parsing)
Right: Use MCP kubernetes tools for structured access
```

## When to Capture the Pattern

After completing a task, ask:

1. **Did this take >5 minutes of systematic work?**
2. **Will someone do this again in the next month?**
3. **Was there a non-obvious trick that made it work?**

If 2+ are true → Offer to author a skill or script.

## Closing

After completing the task:

> "Done. [Summary of what was accomplished]. 
>
> This pattern might be worth capturing if you'll do it again. Want me to author a skill for [specific reusable pattern]?"

## Integration Points

This skill works alongside:
- **Author Skills** - When a pattern is worth capturing
- **Atomic Commit** - When changes need clean commits
- **TDG** - When the task involves testable code
- **Flux Operator** - MCP server for GitOps debugging

---

*"The best automation is the automation you don't need to build because the LLM just does it."*
