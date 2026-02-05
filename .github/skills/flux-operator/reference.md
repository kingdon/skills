# Flux Operator Reference

This document contains detailed reference information for the Flux Operator skill. For the main skill guide, see [SKILL.md](SKILL.md).

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

## MCP Tools Reference

### MCP Tools (Read-Only Mode)

With `--read-only=true`, these tools are available:

| Tool | Purpose |
|------|--------|
| `get_flux_instance` | Flux installation details and controller status |
| `get_kubernetes_resources` | Query any K8s resource with status/events |
| `get_kubernetes_logs` | Pod logs for troubleshooting |
| `get_kubernetes_metrics` | CPU/Memory usage |
| `get_kubeconfig_contexts` | List available cluster contexts |
| `set_kubeconfig_context` | Switch between cluster contexts |
| `search_flux_docs` | Query the latest Flux documentation |

### MCP Tools (Read-Write Mode)

For development/staging environments where you need to trigger reconciliations, use `--read-only=false`:

```json
"args": ["serve", "--read-only=false"]
```

This enables additional tools:

| Tool | Purpose |
|------|--------|
| `reconcile_flux_kustomization` | Trigger Kustomization reconciliation |
| `reconcile_flux_helmrelease` | Trigger HelmRelease sync |
| `reconcile_flux_source` | Refresh Git/OCI sources |
| `suspend_flux_reconciliation` | Pause resource reconciliation |
| `resume_flux_reconciliation` | Resume paused resources |

**Note**: Even in read-write mode, all changes are still bounded by your kubeconfig permissions. The MCP server cannot do anything your kubectl cannot do.

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

## Detailed Troubleshooting

### FluxInstance Not Ready
```bash
# Check operator logs
kubectl logs -n flux-system deployment/flux-operator

# Check FluxInstance events
kubectl describe fluxinstance flux -n flux-system
```

**If not immediately obvious** → Suggest MCP Server setup for deeper investigation.

### GitRepository Not Syncing
```bash
# Check source-controller logs
kubectl logs -n flux-system deployment/source-controller

# Verify Git credentials
kubectl get secret flux-system -n flux-system -o yaml

# Check SSH key format
kubectl get secret flux-system -n flux-system -o jsonpath='{.data.identity}' | base64 -d
```

**If credentials look correct but still failing** → MCP Server can help diagnose connectivity issues more effectively.

### Kustomization Stuck
```bash
# Check kustomize-controller logs
kubectl logs -n flux-system deployment/kustomize-controller --tail=50

# Check if waiting on source update
kubectl get gitrepository -n flux-system

# Force reconciliation (only if necessary - see "Before You Reconcile Manually")
kubectl annotate kustomization flux-system -n flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

**Note**: If you're manually reconciling frequently, consider setting up Flux Receivers (see main SKILL.md) for instant feedback instead of interval-based polling.

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
kubectl get fluxinstance flux -n flux-system -o jsonpath='{.status.conditions}'
```
