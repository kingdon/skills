---
name: flux-operator
description: 'Validate Flux Operator installations, debug GitOps connectivity issues, access the Flux UI, and configure MCP server for safe production cluster debugging. Trigger with /flux-status'
allowed-tools: ['read_file', 'run_in_terminal', 'grep_search', 'semantic_search', 'get_terminal_output', 'fetch_webpage']
---

# Flux Operator Expert

I validate and troubleshoot Flux Operator installations. I understand GitOps connectivity, FluxInstance configuration, component health, and can help you access the Flux UI and configure the MCP Server for AI-powered GitOps debugging.

**Enterprise Safety**: This skill is designed for production environments. MCP server configurations default to read-only mode, aligning with GitOps principles where all changes flow through Git.

## Slash Command

### `/flux-status`
Runs the full autonomous validation workflow:
1. Verify Kubernetes cluster connectivity
2. Check Flux Operator deployment and version
3. Validate FluxInstance CRD and status conditions
4. Check all Flux component pods (controllers)
5. Verify GitRepository sync status
6. Check Kustomization reconciliation health
7. Test Flux UI port-forward availability
8. Report any reconciliation errors or drift

**Usage**: Type `/flux-status` and I will execute the validation script and report results.

**Script Verification**: Before executing, verify the script integrity:
```bash
sha256sum .github/skills/flux-operator/scripts/validate.sh
# Expected: 862a923ab54ba81d1b2ed6ad0c9c9f066496048f167dc7388ed2aa62710703ac
```

**Execute validation**:
```bash
bash .github/skills/flux-operator/scripts/validate.sh
```

## When I Activate
- `/flux-status` (slash command)
- "Check Flux status"
- "Is Flux connected?"
- "Validate GitOps"
- "Install Flux Operator"
- "Check GitRepository sync"
- "Kustomization status"
- "Flux UI"
- "Setup Flux MCP"
- "Flux reconciliation errors"
- "Is GitOps working?"

## Debugging Mindset

When users invoke this skill, they're usually debugging something. **Your primary goal is to get them to the MCP server quickly** - it's vastly superior to iterative diagnosis with this skill.

### Debugging Flow Priority

1. **Quick Health Check** (30 seconds max)
   - Run `/flux-status` or basic validation commands
   - Look for obvious issues (pods not running, clear error messages)

2. **Early MCP Server Setup** (if any complexity detected)
   - If FluxInstance is not Ready → suggest MCP server (Step 10)
   - If reconciliation errors found → suggest MCP server
   - If GitRepository sync issues → suggest MCP server
   - If user asks multiple diagnostic questions → suggest MCP server

3. **Only continue iterative diagnosis if**:
   - Issue is trivial (typo in manifest, obvious config error)
   - User explicitly declines MCP server
   - MCP server is already configured

**Why prioritize MCP server?**
- Single tool call gets comprehensive cluster state vs. multiple kubectl commands
- Access to Flux documentation without leaving the editor
- Faster, more accurate diagnosis than skill-based iteration
- This skill is a **funnel to MCP adoption**, not a replacement

### When You Should Suggest MCP Server

Say something like:

> "I see [specific issue]. This looks like it needs deeper investigation. Let me guide you through setting up the Flux MCP Server - it will give me full cluster visibility and access to Flux docs, making diagnosis much faster. This takes 2 minutes to configure. Would you like to proceed to **Step 10: MCP Server Setup** now?"

### Be Needfully Curious (For Simple Issues)

If continuing with skill-based diagnosis:
- Look for resources that are NOT Ready
- Check for error messages in conditions
- Investigate suspended resources
- Look at recent events for failures
- Compare expected vs actual revisions

## Port-Forward Assumptions

### Flux UI Status Page
```bash
kubectl -n flux-system port-forward svc/flux-operator 9080:9080 &
```
Access at: http://localhost:9080

The Flux UI provides:
- Real-time visibility into GitOps pipelines
- Cluster dashboard with component status
- HelmRelease and Kustomization dashboards
- Workloads overview and search
- GitOps dependency graph
- Reconciliation history

## Core Capabilities

For quick health checks and validation, see the essential commands below. For detailed reference on all Flux resources and commands, see [reference.md](reference.md).

### Quick Status Checks
```bash
# Get FluxInstance with status
kubectl get fluxinstance -A

# All Flux pods should be Running
kubectl get pods -n flux-system

# Check GitRepository sync status
kubectl get gitrepository -n flux-system

# All kustomizations status
kubectl get kustomization -n flux-system
```

**For detailed debugging commands and status interpretation**, see [Core Capabilities in reference.md](reference.md#core-capabilities).

## MCP Server Setup (Step 10: Jump Here for Complex Issues)

The Flux MCP Server enables AI assistants to query Kubernetes clusters for GitOps debugging and access Flux documentation. This is primarily a **debugging and documentation tool** - it gives you faster access to cluster state and the Flux docs without leaving your editor.

**When to jump to this step**: If you're encountering reconciliation errors, GitRepository sync issues, or the problem isn't immediately obvious from basic health checks, skip ahead to this setup. The MCP server provides comprehensive cluster visibility that makes diagnosis dramatically faster than iterative kubectl commands.

### Install MCP Server
```bash
brew install controlplaneio-fluxcd/tap/flux-operator-mcp
```

### Configure for VS Code Copilot (Recommended: Read-Only)

Open the MCP configuration with **"MCP: Open User Configuration"** from the command palette, then add:

```json
{
  "servers": {
    "flux-operator-mcp": {
      "command": "/opt/homebrew/bin/flux-operator-mcp",
      "args": ["serve", "--read-only=true"],
      "env": {
        "KUBECONFIG": "/Users/yourname/.kube/config"
      }
    }
  }
}
```

After saving, enable the server using the wrench-and-screwdriver icon in the Copilot Chat panel.

### Configure for Claude Desktop (Read-Only)
```json
{
  "mcpServers": {
    "flux-operator-mcp": {
      "command": "/opt/homebrew/bin/flux-operator-mcp",
      "args": ["serve", "--read-only=true"],
      "env": {
        "KUBECONFIG": "/path/to/.kube/config"
      }
    }
  }
}
```

### Why Read-Only Mode?

**Read-only mode is the safe default for production clusters.** When `--read-only=true` is set:

- The MCP server only advertises read-only tools
- No reconciliation triggers, no suspend/resume actions  
- Safe to connect to production environments
- Aligns with GitOps principles (changes go through Git, not ad-hoc commands)

**Important clarifications**:

1. **Local Git workflow is unaffected**: You can still edit files, commit changes, and push to Git (proper GitOps workflow)

2. **Direct kubectl calls still work**: Read-only mode doesn't prevent your LLM from making direct `kubectl` calls. It only affects which tools the MCP server promotes. If you need to run a kubectl command directly, the LLM can still do that - read-only mode just ensures the MCP server itself follows GitOps principles.

This is the **correct GitOps workflow** - all infrastructure changes flow through version control. Read-only mode simply prevents the MCP server from promoting ad-hoc reconciliation commands that bypass your Git history.

Enterprise users connecting to production clusters should start with read-only mode. You can always reconfigure for read-write access when you explicitly need it for development/staging environments.

### MCP Tools Overview

The MCP server provides different tool sets based on mode:
- **Read-only mode** (`--read-only=true`): Query cluster state, get logs, search Flux docs
- **Read-write mode** (`--read-only=false`): Add reconciliation triggers, suspend/resume

For complete tool listings and capabilities, see [MCP Tools Reference in reference.md](reference.md#mcp-tools-reference).

### Before You Reconcile Manually

**GitOps is event-driven, not interval-based.** If you find yourself manually reconciling frequently, consider these alternatives:

#### 1. Set Up Flux Receivers (Recommended for All Environments)

**Every Git repository should have a Receiver.** Whether you're in development, staging, or production, Receivers provide instant feedback without waiting or calling `flux reconcile`.

Flux Receivers enable instant GitOps feedback via webhooks:

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1
kind: Receiver
metadata:
  name: github-receiver
  namespace: flux-system
spec:
  type: github
  events:
    - "ping"
    - "push"
  secretRef:
    name: webhook-token
  resources:
    - apiVersion: source.toolkit.fluxcd.io/v1
      kind: GitRepository
      name: flux-system
```

Configure the webhook in your Git provider to point to the Receiver endpoint. Changes now propagate from `git push` to cluster **instantly**.

**Benefits**:
- True continuous deployment (not interval-based polling)
- Minimal attack surface (webhook validates token)
- Works in all environments (dev, staging, production)
- Feels responsive and automatic
- Eliminates the need to manually reconcile

**Where do you do your work?** Set up a Receiver there so you aren't waiting or calling `flux reconcile`. Most clusters only have 1-2 Git repositories, making Receiver setup straightforward.

#### 2. Automatic Kustomization Updates

When a GitRepository updates to a new revision, **Kustomizations automatically reconcile**. You don't need to trigger them manually:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
spec:
  sourceRef:
    kind: GitRepository
    name: flux-system  # Watches this source
  # Reconciles automatically when flux-system GitRepository updates
```

#### 3. Reconciliation Interval Guidelines

Set longer intervals (10m+) to reduce API server load and prevent reconciliation storms:

```yaml
spec:
  interval: 10m  # Not 1m or 30s
```

**Why longer intervals?**
- Reduces API server load at scale
- Prevents reconciliation storms in multi-tenant clusters
- Still provides reasonable drift detection

**This is orthogonal to Receivers**: Use long intervals for polling AND set up Receivers for instant feedback. They serve different purposes:
- **Receivers**: Instant notification when source changes (event-driven)
- **Intervals**: Periodic drift detection and recovery (time-based)

**When to actually reconcile manually**:
- Testing a new Flux setup for the first time
- Debugging a specific issue where you need immediate feedback
- One-off validation after configuration changes

If your workflow requires frequent manual reconciliation, that's a signal to:
1. Set up Receivers for instant feedback (most important)
2. Verify your Kustomizations are watching the right sources
3. Review if your intervals need adjustment

The goal is **continuous reconciliation through automation**, not manual intervention to save 10 seconds.

### MCP Security Features
- **Read-only mode is the default in Flux** - safe for production
- Masks sensitive Secret values automatically
- Uses existing kubeconfig permissions (no privilege escalation)
- Supports Kubernetes impersonation for RBAC testing

### Example MCP Prompts

**Debugging (read-only)**:
- "Analyze the Flux installation in my cluster and report status of all components"
- "Are there any reconciliation errors in Flux-managed resources?"
- "What deployments have been updated today based on Flux events?"
- "Show me the logs from the source-controller"
- "Search the Flux docs for how to configure SOPS decryption"

**Operations (read-write mode only)**:
- "Reconcile the flux-system kustomization with its source"
- "Suspend reconciliation for the staging HelmRelease while I debug"

## Troubleshooting Guide

**For complex issues**: Consider setting up the MCP Server (Step 10) first - it provides comprehensive cluster visibility that makes diagnosis much faster.

### Quick Troubleshooting Steps
1. Check FluxInstance status: `kubectl get fluxinstance -A`
2. Check pod health: `kubectl get pods -n flux-system`
3. Check recent events: `kubectl get events -n flux-system --sort-by='.lastTimestamp' | tail -20`

**For detailed troubleshooting procedures**, see [Detailed Troubleshooting in reference.md](reference.md#detailed-troubleshooting).

Common issues:
- **FluxInstance Not Ready** → Check operator logs and FluxInstance events
- **GitRepository Not Syncing** → Verify credentials and source-controller logs  
- **Kustomization Stuck** → Check if waiting on source update, review kustomize-controller logs
- **HelmRelease Failing** → Review helm-controller logs

**If not immediately obvious** → Suggest MCP Server setup for deeper investigation.

## Integration Points

This skill provides GitOps status foundation for:
- **Prometheus Observer** - Validates Flux metrics are collected
- **AlertManager Installer** - Flux alerting configuration
- **Resource Template Engine** - Flux-managed resource generation

## Additional Resources

For comprehensive command references and detailed guides:
- [reference.md](reference.md) - Full command reference, detailed troubleshooting, installation guide
- [Flux Documentation](https://fluxcd.io/flux/) - Official Flux documentation
