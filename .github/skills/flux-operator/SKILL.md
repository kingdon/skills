```skill
---
name: flux-operator
description: 'Install and validate Flux Operator installations, check GitOps connectivity, access the Flux UI status page, and configure MCP server integration. Trigger with /flux-status'
allowed-tools: ['read_file', 'run_in_terminal', 'grep_search', 'semantic_search', 'get_terminal_output', 'fetch_webpage']
---

# Flux Operator Expert

I install, validate, and troubleshoot Flux Operator installations. I understand GitOps connectivity, FluxInstance configuration, component health, and can help you access the Flux UI and configure the MCP Server for AI-powered GitOps.

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

When users invoke this skill, they're usually debugging something. Be **needfully curious**:
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

### 1. FluxInstance Status Validation
Check the primary FluxInstance resource for Ready condition:

```bash
# Get FluxInstance with status
kubectl get fluxinstance -A

# Detailed status with conditions
kubectl get fluxinstance flux -n flux-system -o jsonpath='{.status.conditions}' | jq .
```

**Expected Ready Condition**:
```json
{
  "type": "Ready",
  "status": "True",
  "reason": "ReconciliationSucceeded",
  "message": "Reconciliation finished in 1s"
}
```

**Failure Indicators**:
- `status: "False"` - Something is broken
- `reason: "ReconciliationFailed"` - Check message for details
- Missing revision info - Sync not completing

### 2. Component Health Verification
```bash
# All Flux pods should be Running
kubectl get pods -n flux-system

# Expected components:
# - flux-operator-*
# - source-controller-*
# - kustomize-controller-*
# - helm-controller-*
# - notification-controller-*
```

### 3. GitRepository Sync Status
```bash
# Check sync status
kubectl get gitrepository -n flux-system

# Detailed with revision
kubectl get gitrepository flux-system -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
```

**Healthy Output**:
```
READY   STATUS
True    stored artifact for revision 'refs/heads/main@sha1:abc123...'
```

### 4. Kustomization Reconciliation
```bash
# All kustomizations status
kubectl get kustomization -n flux-system

# Check specific kustomization conditions
kubectl get kustomization flux-system -n flux-system \
  -o jsonpath='{range .status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.message}{"\n"}{end}'
```

## Kubernetes Object Ready Conditions

Flux resources follow the KStatus pattern. Key conditions to check:

| Condition | Meaning |
|-----------|---------|
| `Ready` | Resource has successfully reconciled |
| `Stalled` | Reconciliation cannot make progress |
| `Reconciling` | Actively processing changes |

### Checking Any Flux Object
```bash
# Generic pattern for any Flux resource
kubectl get <kind> <name> -n <namespace> \
  -o jsonpath='{.status.conditions}' | jq '.[] | {type, status, message, reason}'
```

### Common Status Messages
- **"Applied revision: refs/heads/main@sha1:..."** - Success, synced to this commit
- **"Dependency 'flux-system/flux-system' is not ready"** - Waiting for dependency
- **"Source not found"** - GitRepository missing or not synced
- **"kustomize build failed"** - Invalid manifests in repository

## Installation Guide

### Prerequisites
- Kubernetes cluster (1.28+)
- kubectl configured with cluster access
- Homebrew (for CLI installation on macOS/Linux)

### Install Flux Operator CLI
```bash
brew install controlplaneio-fluxcd/tap/flux-operator
```

### Deploy Flux Operator and Instance
```yaml
# flux-instance.yaml
apiVersion: fluxcd.controlplane.io/v1
kind: FluxInstance
metadata:
  name: flux
  namespace: flux-system
spec:
  distribution:
    version: "2.x"
    registry: "ghcr.io/fluxcd"
    artifact: "oci://ghcr.io/controlplaneio-fluxcd/flux-operator-manifests"
  components:
    - source-controller
    - source-watcher
    - kustomize-controller
    - helm-controller
    - notification-controller
  cluster:
    type: kubernetes
    size: medium
    multitenant: false
    networkPolicy: true
    domain: "cluster.local"
```

Apply with:
```bash
flux-operator install -f flux-instance.yaml
```

### Configure Git Sync
```yaml
spec:
  sync:
    kind: GitRepository
    url: "ssh://git@github.com/org/repo.git"
    ref: "refs/heads/main"
    path: "clusters/my-cluster"
    pullSecret: "flux-system"
```

### Create Git Credentials
```bash
flux-operator create secret basic-auth flux-system \
  --namespace=flux-system \
  --username=git \
  --password=$GITHUB_TOKEN
```

## Flux UI Status Page

The Flux Operator includes a built-in web UI at port 9080.

### Access via Port-Forward
```bash
kubectl -n flux-system port-forward svc/flux-operator 9080:9080 &
```

Open http://localhost:9080 in your browser.

### Features
- **Cluster Dashboard**: Overview of all Flux components and their health
- **Kustomization Dashboard**: Detailed view of each Kustomization
- **HelmRelease Dashboard**: Helm chart deployments and revisions
- **Workloads Overview**: All managed Kubernetes workloads
- **GitOps Graph**: Visual dependency mapping
- **Reconciliation History**: Track changes over time
- **Advanced Search**: Find resources across namespaces

## MCP Server Setup

The Flux MCP Server enables AI assistants to interact with Kubernetes clusters for GitOps operations.

### Install MCP Server
```bash
brew install controlplaneio-fluxcd/tap/flux-operator-mcp
```

### Configure for VS Code Copilot
Add to VS Code settings:
```json
{
  "mcp": {
    "servers": {
      "flux-operator-mcp": {
        "command": "/opt/homebrew/bin/flux-operator-mcp",
        "args": ["serve"],
        "env": {
          "KUBECONFIG": "/Users/yourname/.kube/config"
        }
      }
    }
  },
  "chat.mcp.enabled": true
}
```

### Configure for Claude Desktop
```json
{
  "mcpServers": {
    "flux-operator-mcp": {
      "command": "/opt/homebrew/bin/flux-operator-mcp",
      "args": ["serve", "--read-only=false"],
      "env": {
        "KUBECONFIG": "/path/to/.kube/config"
      }
    }
  }
}
```

### MCP Security Features
- Read-only mode available (`--read-only=true`)
- Masks sensitive Secret values
- Uses existing kubeconfig permissions
- Supports Kubernetes impersonation

### MCP Tools Available
Once configured, the MCP server provides:

**Reporting**:
- `get_flux_instance` - Flux installation details
- `get_kubernetes_resources` - Any K8s resource with status/events
- `get_kubernetes_logs` - Pod logs for troubleshooting
- `get_kubernetes_metrics` - CPU/Memory usage

**Actions**:
- `reconcile_flux_kustomization` - Trigger reconciliation
- `reconcile_flux_helmrelease` - Trigger Helm sync
- `reconcile_flux_source` - Refresh Git/OCI sources
- `suspend_flux_reconciliation` - Pause resources
- `resume_flux_reconciliation` - Resume paused resources

**Documentation**:
- `search_flux_docs` - Query latest Flux documentation

### Example MCP Prompts
After MCP is configured:
- "Analyze the Flux installation in my cluster and report status of all components"
- "Are there any reconciliation errors in Flux-managed resources?"
- "Reconcile the flux-system kustomization with its source"
- "What deployments have been updated today based on Flux events?"
- "Draw a diagram of the Flux dependency flow"

## Troubleshooting Guide

### FluxInstance Not Ready
```bash
# Check operator logs
kubectl logs -n flux-system deployment/flux-operator

# Check FluxInstance events
kubectl describe fluxinstance flux -n flux-system
```

### GitRepository Not Syncing
```bash
# Check source-controller logs
kubectl logs -n flux-system deployment/source-controller

# Verify Git credentials
kubectl get secret flux-system -n flux-system -o yaml

# Check SSH key format
kubectl get secret flux-system -n flux-system -o jsonpath='{.data.identity}' | base64 -d
```

### Kustomization Stuck
```bash
# Check kustomize-controller logs
kubectl logs -n flux-system deployment/kustomize-controller --tail=50

# Force reconciliation
kubectl annotate kustomization flux-system -n flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

### HelmRelease Failing
```bash
# Check helm-controller logs
kubectl logs -n flux-system deployment/helm-controller --tail=50

# Get HelmRelease status
kubectl get helmrelease -A -o custom-columns=\
NAME:.metadata.name,READY:.status.conditions[0].status,MESSAGE:.status.conditions[0].message
```

## Quick Health Check Commands

```bash
# One-liner: All Flux resources health
kubectl get fluxinstance,gitrepository,kustomization,helmrelease -A

# Check for NOT Ready resources
kubectl get kustomization -A -o jsonpath='{range .items[?(@.status.conditions[0].status!="True")]}{.metadata.namespace}/{.metadata.name}: {.status.conditions[0].message}{"\n"}{end}'

# Recent events for debugging
kubectl get events -n flux-system --sort-by='.lastTimestamp' | tail -20
```

## Integration Points

This skill provides GitOps status foundation for:
- **Prometheus Observer** - Validates Flux metrics are collected
- **AlertManager Installer** - Flux alerting configuration
- **Resource Template Engine** - Flux-managed resource generation

## Read-Only Commands Reference

Safe commands that only observe, never modify:

```bash
# Cluster status
kubectl get fluxinstance -A
kubectl get pods -n flux-system
kubectl get gitrepository -A
kubectl get kustomization -A
kubectl get helmrelease -A

# Detailed inspection
kubectl describe fluxinstance flux -n flux-system
kubectl get events -n flux-system

# Version info
flux-operator version
kubectl get fluxinstance flux -n flux-system -o jsonpath='{.status.revision}'
```
```
