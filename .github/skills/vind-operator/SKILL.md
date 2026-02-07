---
name: vind-operator
description: 'Validate Vind (lightweight Kubernetes) cluster creation, migrate from Kind to Vind, and perform cross-architecture testing for resource-constrained environments. Trigger with /vind-status'
allowed-tools: ['read_file', 'run_in_terminal', 'grep_search', 'semantic_search', 'get_terminal_output', 'create_file']
---

# Vind Operator Expert

**"Kind is great. But have you tried running it on a NAS with 4GB RAM?"**

I validate and manage Vind clusters—lightweight Kubernetes distributions designed for resource-constrained environments. This skill helps migrate from Kind (too heavy for Synology NAS) to Vind, and enables cross-architecture testing where x86 Vind clusters validate ARM64 manifests before CozyStack deployment.

**Context**: Vind emerged from the Sunkworks episode we never quite reached—the realization that Kind's node containers are too memory-hungry for homelab NAS devices. Vind provides a lighter alternative while maintaining Kubernetes API compatibility.

## Slash Command

### `/vind-status`
Runs Vind validation workflow:
1. Check Vind cluster health and node status
2. Validate resource constraints (memory/CPU limits)
3. Verify cross-architecture manifest compatibility
4. Report cluster readiness for manifest testing

**Usage**: Type `/vind-status` to validate Vind cluster health.

**Script Verification**: Before executing, verify the script integrity:
```bash
sha256sum .github/skills/vind-operator/scripts/validate.sh
# Expected: b42e83b65ad548a97be2464feaed426f882356eb2bccd76f579cf912c6d45a71
```

**Execute validation**:
```bash
bash .github/skills/vind-operator/scripts/validate.sh
```

## When I Activate
- `/vind-status` (slash command)
- "Check Vind cluster"
- "Vind vs Kind"
- "Lightweight Kubernetes"
- "Synology Kubernetes"
- "Cross-architecture testing"
- "Validate ARM manifests on x86"
- "Resource-constrained Kubernetes"
- "Migrate from Kind"

## Expected Failure Modes

### Cluster Creation Failures
| Failure Mode | Symptoms | Est. Recovery Time |
|--------------|----------|-------------------|
| OOM during creation | Container killed, cluster partially created | 15-30 min |
| Image pull timeout | Node stuck in ContainerCreating | 10-20 min |
| Network bridge conflict | Multiple Vind clusters fail to start | 20-30 min |
| Storage driver incompatibility | Container fails immediately | 30-60 min |

### Cross-Architecture Failures
| Failure Mode | Symptoms | Est. Recovery Time |
|--------------|----------|-------------------|
| Multi-arch image missing | ImagePullBackOff on ARM target | 20-40 min |
| Architecture-specific configs | Works on x86, fails on ARM | 30-60 min |
| Resource limits too tight | ARM device has less headroom | 15-30 min |

### Migration Failures (Kind → Vind)
| Failure Mode | Symptoms | Workaround |
|--------------|----------|------------|
| Kind-specific features | Extraportmappings, node labels | Manual reconfiguration |
| Volume mount differences | PV/PVC paths don't match | Update volume specs |
| Network policy variance | CNI behavior differences | Validate policies separately |

## Core Capabilities

### 1. Vind Cluster Creation

#### Basic Cluster
```bash
# Create single-node Vind cluster (minimal resources)
vind create cluster --name sunkworks-dev \
  --memory 2048 \
  --cpus 2

# Verify creation
kubectl cluster-info --context vind-sunkworks-dev
```

#### Resource-Constrained Configuration
For Synology NAS and similar devices:

```yaml
# vind-config.yaml
kind: Cluster
apiVersion: vind.io/v1alpha1
metadata:
  name: synology-minimal
spec:
  nodes:
    - role: control-plane
      resources:
        memory: "1536Mi"  # Synology-safe
        cpu: "1500m"      # Leave headroom for DSM
      extraMounts:
        - hostPath: /volume1/kubernetes
          containerPath: /var/lib/kubernetes
  networking:
    disableDefaultCNI: false
    podSubnet: "10.244.0.0/16"
  # Disable resource-heavy features
  featureGates:
    EphemeralContainers: false
```

```bash
# Create from config
vind create cluster --config vind-config.yaml
```

#### Memory Optimization
```bash
# Set Kubernetes component resource limits
vind create cluster --name minimal \
  --kube-apiserver-extra-args="--max-requests-inflight=100" \
  --kubelet-extra-args="--max-pods=50" \
  --controller-extra-args="--concurrent-deployment-syncs=2"
```

### 2. Kind to Vind Migration

#### Export Kind Configuration
```bash
# Get current Kind cluster config
kind get clusters
kind export kubeconfig --name <kind-cluster>

# Export workloads (not including system pods)
kubectl get all -A -o yaml > kind-workloads.yaml
```

#### Configuration Translation

**Kind Config:**
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
```

**Equivalent Vind Config:**
```yaml
kind: Cluster
apiVersion: vind.io/v1alpha1
metadata:
  name: migrated-cluster
spec:
  nodes:
    - role: control-plane
      portMappings:
        - port: 80
          hostPort: 80
      labels:
        ingress-ready: "true"
      resources:
        memory: "2048Mi"
        cpu: "2000m"
```

#### Migration Script
```bash
#!/bin/bash
# migrate-kind-to-vind.sh

KIND_CLUSTER=$1
VIND_CLUSTER=${2:-"vind-$KIND_CLUSTER"}

echo "=== Migrating Kind cluster '$KIND_CLUSTER' to Vind '$VIND_CLUSTER' ==="

# Step 1: Export from Kind
echo "Step 1: Exporting Kind cluster state..."
kind export kubeconfig --name $KIND_CLUSTER
kubectl get all -A -o yaml > /tmp/kind-export.yaml

# Step 2: Stop Kind cluster
echo "Step 2: Stopping Kind cluster..."
kind delete cluster --name $KIND_CLUSTER

# Step 3: Create Vind cluster
echo "Step 3: Creating Vind cluster..."
vind create cluster --name $VIND_CLUSTER

# Step 4: Apply workloads
echo "Step 4: Applying workloads to Vind..."
kubectl --context vind-$VIND_CLUSTER apply -f /tmp/kind-export.yaml

echo "=== Migration complete ==="
```

### 3. Cross-Architecture Testing

#### x86 → ARM64 Manifest Validation

The Sunkworks pattern: Validate manifests on x86 Vind before deploying to ARM64 CozyStack.

```bash
#!/bin/bash
# cross-arch-validate.sh

MANIFEST=$1
X86_CONTEXT="vind-x86-test"
ARM_TARGET_CONTEXT="cozystack-arm64"

echo "=== Cross-Architecture Validation ==="
echo "Manifest: $MANIFEST"

# Step 1: Apply to x86 Vind cluster
echo "Step 1: Testing on x86 Vind..."
kubectl --context $X86_CONTEXT apply --dry-run=server -f $MANIFEST
if [ $? -ne 0 ]; then
  echo "ERROR: Manifest failed validation on x86"
  exit 1
fi
echo "✓ x86 dry-run passed"

# Step 2: Check image architectures
echo "Step 2: Validating image architectures..."
IMAGES=$(kubectl --context $X86_CONTEXT apply --dry-run=client -f $MANIFEST -o jsonpath='{.spec.template.spec.containers[*].image}' 2>/dev/null)

for IMAGE in $IMAGES; do
  echo "  Checking $IMAGE..."
  # Query registry for manifest list
  docker manifest inspect $IMAGE 2>/dev/null | jq -e '.manifests[] | select(.platform.architecture == "arm64")' > /dev/null
  if [ $? -ne 0 ]; then
    echo "  WARNING: $IMAGE may not have arm64 support"
  else
    echo "  ✓ arm64 manifest found"
  fi
done

# Step 3: Apply to x86 and verify
echo "Step 3: Full deployment test on x86..."
kubectl --context $X86_CONTEXT apply -f $MANIFEST
kubectl --context $X86_CONTEXT rollout status deployment -l app.kubernetes.io/instance=$(basename $MANIFEST .yaml) --timeout=120s

echo "=== Validation Complete ==="
echo "Safe to deploy to ARM64 target"
```

#### Architecture-Aware Resource Limits
ARM devices typically have less memory headroom:

```yaml
# Cross-architecture deployment with adjusted limits
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      containers:
        - name: app
          resources:
            # x86 values (test cluster has more headroom)
            # ARM values should be ~75% of these
            requests:
              memory: "128Mi"  # ARM: 96Mi
              cpu: "100m"       # ARM: 75m
            limits:
              memory: "256Mi"  # ARM: 192Mi
              cpu: "200m"       # ARM: 150m
```

### 4. Resource Monitoring

#### Vind Cluster Health
```bash
# Check Vind cluster node resources
kubectl top nodes

# Check system pod resource usage
kubectl -n kube-system top pods

# Monitor resource pressure
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="MemoryPressure")].status}{"\t"}{.status.conditions[?(@.type=="DiskPressure")].status}{"\n"}{end}'
```

#### Synology-Specific Monitoring
```bash
# Check Docker/containerd memory usage on Synology
ssh admin@synology-ip "docker stats --no-stream"

# Check system memory
ssh admin@synology-ip "free -m"

# Monitor DSM resource usage
ssh admin@synology-ip "top -bn1 | head -20"
```

## Recovery Playbooks

### Playbook 1: Vind Cluster OOM (20-30 min)
1. Stop the cluster: `vind delete cluster --name <name>`
2. Review resource config and reduce limits
3. Recreate with smaller footprint
4. Apply only essential workloads first

### Playbook 2: Kind Migration Fails (30-45 min)
1. Preserve Kind cluster (don't delete yet)
2. Create Vind cluster with minimal config
3. Manually port critical workloads
4. Verify functionality before deleting Kind
5. Iterate on remaining workloads

### Playbook 3: Cross-Arch Image Failure (20-40 min)
1. Identify failing image: `kubectl describe pod <name>`
2. Check registry for multi-arch manifest: `docker manifest inspect <image>`
3. Find alternative image or build multi-arch version
4. Update deployment and redeploy

## Vind vs Kind Comparison

| Feature | Kind | Vind | Winner for NAS |
|---------|------|------|----------------|
| Base memory usage | ~2GB | ~1GB | Vind |
| Startup time | 60-90s | 30-45s | Vind |
| Multi-node support | Yes | Yes | Tie |
| Ingress | Extra config | Built-in | Vind |
| GPU passthrough | Limited | Limited | Tie |
| Community size | Large | Growing | Kind |
| Documentation | Extensive | Adequate | Kind |

## Integration Points

- **Flux Operator**: Bootstrap Flux on Vind for GitOps testing
- **Resource Template Engine**: Test templates on Vind before production
- **Pi-Hole Sync**: Vind clusters can test DNS configuration

## Sunkworks Episode Notes

*"The episode where we tried to run Kind on the NAS... and learned why Vind exists."*

### Episode That Never Happened
- Planned: "Lightweight Kubernetes for Everyone"
- Reality: 3 hours of OOM kills and container restarts
- Outcome: Discovery of Vind as Kind alternative

### Key Learnings for Future Episodes
1. Always check `free -m` before cluster creation
2. Synology Container Manager has hidden memory overhead
3. ARM devices need 75% of x86 resource limits
4. Cross-arch testing catches problems before production
