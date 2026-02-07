---
name: crossplane-provider-surgery
description: 'Diagnose and repair Crossplane Kubernetes & Helm provider connectivity issues in EKS compositions. Guides operators through AccessEntry/ClusterAuth investigation when GitOps sync fails. Trigger with /crossplane-surgery'
allowed-tools: ['read_file', 'run_in_terminal', 'grep_search', 'semantic_search', 'get_terminal_output']
---

# Crossplane Provider Surgery Expert

I guide operators through diagnosing and surgically repairing Crossplane provider connectivity issues. I understand the EKS composition dependency chain and help you investigate AccessEntry/ClusterAuth failures that prevent GitOps sync.

**This pattern applies to**: Any Crossplane composition that creates EKS clusters with Kubernetes/Helm providers, including AWS Blueprints patterns and custom compositions.

## Slash Command

### `/crossplane-surgery`
Runs the automated diagnostic workflow then guides repair:
1. **Automated Diagnosis**: Execute validation script to detect unhealthy providers
2. **Root Cause Analysis**: Test kubeconfig connectivity and compare AccessEntry IAM ARNs
3. **Compare Reference**: Diff broken cluster against healthy cluster in same account
4. **Report Findings**: Identify which layer failed (Secret → ClusterAuth → AccessEntry)
5. **Guide Repair**: Walk human through surgical intervention with confirmation at each step

**Usage**: Type `/crossplane-surgery` and I will run the diagnostic script and guide you through repair.

**Execute diagnosis**:
```bash
# Specify target and reference clusters
bash .github/skills/crossplane-provider-surgery/scripts/diagnose.sh $TARGET $REFERENCE

# Example with personal accounts
bash .github/skills/crossplane-provider-surgery/scripts/diagnose.sh urmanac-prod urmanac-test
```

**This is a guided workflow** - The script diagnoses automatically, but repair requires human confirmation at each destructive step.

## When I Activate
- `/crossplane-surgery` (slash command)
- "IRSA stuck InProgress"
- "Provider not syncing"
- "ProviderConfig has zero users"
- "Crossplane can't reach cluster"
- "AccessEntry problem"
- "ClusterAuth broken"
- "Kubernetes provider not working"
- "Helm releases not deploying"

## When NOT To Use This Skill
- Crossplane provider version upgrades
- Kubernetes version upgrades  
- IAM policy changes (use AWS console)
- Network/VPC connectivity problems
- Crossplane core controller issues
- Cluster needs full deletion/recreation

## Debugging Mindset

This is **investigative surgery**. Be needfully curious:
- The symptom (ProviderConfig zero users) is NOT the cause
- AccessEntry may show Ready=True but have wrong IAM ARN
- IAM is not regional - same-account clusters MUST have identical ARNs
- Peel layers until you find the actual failure
- Test connectivity at each layer before proceeding

## Problem Context

This issue occurs when:
- A cluster is accidentally deleted and recreated
- Two clusters are written to the same namespace (composition limitation until Crossplane v2)
- AccessEntries are misconfigured but AWS reports Ready=True

**The symptom**: Flux detects IRSA, ExternalDNS, or EKS cluster resources stuck InProgress. ProviderConfig shows low/zero `status.users`. The underlying AccessEntry/ClusterAuth kubeconfig can't authenticate.

## The Dependency Chain

Understanding this chain is critical for **both diagnosis AND deletion order**:

```
AccessEntry (may have wrong IAM ARN)
  → AccessPolicyAssociation (grants permissions via AccessEntry)
    → ClusterAuth (generates kubeconfig using AccessEntry permissions)
      → Secret in crossplane-system (stores kubeconfig)
        → ProviderConfig (references secret)
          → Objects/Releases (use ProviderConfig, protected by Usages)
            → IRSA/ExternalDNS compositions (depend on Objects)
              → Flux Kustomizations (wait for composition health)
```

**DELETION ORDER IS THE REVERSE**: Delete from leaves (Objects/Releases) up to the root (ClusterAuth).

**Key Insight**: Usages protect resources from deletion. Objects hold Usages on ProviderConfig, which holds Usages on ClusterAuth. You must delete the Objects first, then their Usages auto-delete, allowing ClusterAuth deletion.

## Common Composition Patterns

### IRSA Pattern (IAM Roles for Service Accounts)
Creates an IAM Role with IAM Policy and maps it to a Kubernetes ServiceAccount via OIDC. This is a well-known pattern used across the Crossplane community.

```yaml
# Conceptual structure
apiVersion: your.domain/v1alpha1
kind: IRSAComposition
spec:
  # Creates:
  # - IAM Role with trust policy for OIDC provider
  # - IAM Policy with required permissions
  # - Kubernetes ServiceAccount annotated with role ARN
```

### AWS Blueprints Pattern
If using [EKS Blueprints for CDK](https://aws.amazon.com/blogs/containers/amazon-eks-blueprints-for-cdk-now-supporting-amazon-eks-auto-mode/), your compositions may follow similar patterns with AccessEntry/AccessPolicyAssociation for cluster authentication.

---

## Phase 1: Initial Diagnosis

**Objective:** Identify which cluster(s) have broken providers and confirm the scope.

> 💡 **Variable Convention**: Replace `$TARGET` with broken cluster name (e.g., `urmanac-prod`), `$REFERENCE` with working cluster (e.g., `urmanac-test`)

### 1.1 Check Flux for Failing Kustomizations
```bash
kubectl get kustomization -n flux-system -o json | \
  jq -r '.items[] | select(.status.conditions[]? | select(.type=="Healthy" and .status=="False")) | 
  "\(.metadata.name): \(.status.conditions[] | select(.type=="Healthy") | .message)"'
```
**Look for**: Timeouts on IRSA, ExternalDNS, or EKS cluster resources.

### 1.2 List ProviderConfigs with User Counts
```bash
# Kubernetes providers - sorted by user count
kubectl get providerconfig.kubernetes.crossplane.io -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.status.users // 0) users"' | sort -t: -k2 -n

# Helm providers  
kubectl get providerconfig.helm.crossplane.io -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.status.users // 0) users"' | sort -t: -k2 -n
```
**Healthy**: 8-20+ users. **Broken**: 0-2 users.

### 1.3 Compare Target vs Reference Cluster
```bash
# Quick comparison - both should exist and have similar user counts
kubectl get providerconfig.kubernetes.crossplane.io $TARGET $REFERENCE \
  -o jsonpath='{range .items[*]}{.metadata.name}: {.status.users} users{"\n"}{end}'
```

---

## Phase 2: Peel the Onion

**Objective:** Trace from symptoms down to root cause.

### 2.1 Find Stuck Objects on Target ProviderConfig
```bash
# Kubernetes Objects not Ready
kubectl get object.kubernetes.crossplane.io -A -o json | \
  jq -r '.items[] | select(.spec.providerConfigRef.name=="'$TARGET'") | 
  "\(.metadata.namespace)/\(.metadata.name): \(.status.conditions[]? | select(.type=="Ready") | .status)"'
```

### 2.2 Check ProviderConfigUsages
```bash
kubectl get providerconfigusage.kubernetes.crossplane.io -o json | \
  jq -r '.items[] | select(.spec.providerConfigRef.name=="'$TARGET'") | 
  "\(.metadata.name): using \(.spec.of.kind)/\(.spec.of.name)"'
```

### 2.3 Inspect ClusterAuth Secret
```bash
# Get secret name from ProviderConfig
SECRET=$(kubectl get providerconfig.kubernetes.crossplane.io $TARGET \
  -o jsonpath='{.spec.credentials.secretRef.name}')
echo "Secret: $SECRET"

# Check if secret exists
kubectl get secret -n crossplane-system $SECRET
```

### 2.4 Test Kubeconfig Connectivity (THE KEY TEST)
```bash
# Extract and test
kubectl get secret -n crossplane-system $SECRET \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/test-kubeconfig.yaml

# Test connectivity
KUBECONFIG=/tmp/test-kubeconfig.yaml kubectl get nodes
KUBECONFIG=/tmp/test-kubeconfig.yaml kubectl auth can-i '*' '*' --all-namespaces
```
**Expected failure**: Authentication errors, permission denied, or connection refused.

### 2.5 Compare AccessEntry IAM ARNs
```bash
# Target (broken) - adapt the label selector to your composition
kubectl get accessentry.eks.aws.upbound.io -o json | \
  jq -r '.items[] | select(.metadata.name | contains("'$TARGET'")) | 
  {name: .metadata.name, arn: .spec.forProvider.principalArn}'

# Reference (working)
kubectl get accessentry.eks.aws.upbound.io -o json | \
  jq -r '.items[] | select(.metadata.name | contains("'$REFERENCE'")) | 
  {name: .metadata.name, arn: .spec.forProvider.principalArn}'
```
**IAM is not regional** - same-account clusters MUST have identical role ARNs!

---

## Phase 3: Surgical Intervention

**⚠️ CONFIRM EACH STEP WITH HUMAN BEFORE PROCEEDING ⚠️**

> 💡 **Lesson Learned**: Sometimes targeted fixes (delete just ClusterAuth) don't work due to stale internal state. The "nuclear option" - complete purge from leaves to ClusterAuth - consistently succeeds.

### 3.1 Pause ALL Affected Compositions

Adapt these commands to your composition's CRD kind:

```bash
# Find and pause the main cluster XR (replace with your CRD kind)
XR=$(kubectl get <your-eks-xr-kind> -o json | \
  jq -r '.items[] | select(.metadata.name | contains("'$TARGET'")) | .metadata.name' | head -1)

kubectl annotate <your-eks-xr-kind> $XR crossplane.io/paused=true

# CRITICAL: Pause ALL dependent compositions too!
# Replace with your composition kinds (IRSA, ExternalDNS, etc.)
kubectl get <irsa-xr-kind> -o name | xargs -I {} kubectl annotate {} crossplane.io/paused=true
kubectl get <externaldns-xr-kind> -o name | xargs -I {} kubectl annotate {} crossplane.io/paused=true

# Verify paused
kubectl get <your-eks-xr-kind> $XR -o jsonpath='{.metadata.annotations.crossplane\.io/paused}'
```

### 3.2 Delete Zombie Objects (THE LEAVES)

**Delete Objects FIRST** - they hold Usages that block everything else:

```bash
# Objects that never synced still have finalizers - clear them
for obj in $(kubectl get object.kubernetes.crossplane.io -o name | grep $TARGET); do
  echo "Clearing finalizers on $obj"
  kubectl patch $obj -p '{"metadata":{"finalizers":[]}}' --type=merge
done

# Delete all Objects for this ProviderConfig
kubectl delete object.kubernetes.crossplane.io -l crossplane.io/claim-namespace=$TARGET

# Same for Helm Releases
for rel in $(kubectl get release.helm.crossplane.io -o name | grep $TARGET); do
  kubectl patch $rel -p '{"metadata":{"finalizers":[]}}' --type=merge
done
kubectl delete release.helm.crossplane.io -l crossplane.io/claim-namespace=$TARGET
```

### 3.3 Clear ProviderConfigUsages (auto-deleted with Objects, verify)
```bash
# ProviderConfigUsages usually auto-delete when their parent Objects are deleted.
# Verify they're gone:
kubectl get providerconfigusage.kubernetes.crossplane.io -o json | \
  jq -r '.items[] | select(.spec.providerConfigRef.name=="'$TARGET'") | .metadata.name'

# If any remain, delete manually:
kubectl delete providerconfigusage.kubernetes.crossplane.io \
  -l crossplane.io/provider-config-name=$TARGET
kubectl delete providerconfigusage.helm.crossplane.io \
  -l crossplane.io/provider-config-name=$TARGET
```

### 3.4 Delete Usages Blocking ClusterAuth

```bash
# List Usages protecting ClusterAuth
kubectl get usage -o json | jq -r '.items[] | 
  select(.spec.of.kind=="ClusterAuth") | 
  select(.metadata.name | contains("'$TARGET'")) | .metadata.name'

# Delete them (they should be orphaned now that Objects are gone)
kubectl get usage -o name | grep $TARGET | xargs kubectl delete
```

### 3.5 Delete AccessPolicyAssociations (if doing full purge)

```bash
# These may need to be recreated fresh
kubectl delete accesspolicyassociation.eks.aws.upbound.io \
  -l crossplane.io/claim-name=$TARGET-cluster
```

### 3.6 Delete ClusterAuth (THE ROOT CAUSE)

```bash
# Now ClusterAuth should have no blocking Usages
# Find and delete it:
CLUSTERAUTH=$(kubectl get clusterauth.eks.aws.upbound.io -o json | \
  jq -r '.items[] | select(.metadata.name | contains("'$TARGET'")) | .metadata.name')

kubectl delete clusterauth.eks.aws.upbound.io $CLUSTERAUTH

# Verify it's gone
kubectl get clusterauth.eks.aws.upbound.io | grep $TARGET
```

> ⚠️ **DO NOT delete the Cluster resource or its protection Usage!** Only delete down to ClusterAuth level.

### 3.7 Unpause EKS Composition FIRST

```bash
# Unpause the EKS XR - this triggers ClusterAuth regeneration
kubectl annotate <your-eks-xr-kind> $XR crossplane.io/paused-

# Wait for ClusterAuth to regenerate (1-2 minutes)
watch 'kubectl get clusterauth.eks.aws.upbound.io | grep $TARGET'
```

### 3.8 Validate Regenerated Kubeconfig

```bash
# Run the diagnostic to test connectivity
bash .github/skills/crossplane-provider-surgery/scripts/diagnose.sh $TARGET

# Or manually test:
SECRET=$(kubectl get providerconfig.kubernetes.crossplane.io $TARGET \
  -o jsonpath='{.spec.credentials.secretRef.name}')
kubectl get secret -n crossplane-system $SECRET \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/new-kubeconfig.yaml
KUBECONFIG=/tmp/new-kubeconfig.yaml kubectl get nodes
```
**Expected**: Full cluster-admin access works now. If not, investigate AccessEntry IAM ARN.

### 3.9 Unpause Dependent Compositions

```bash
# Only after kubeconfig is verified working!
kubectl annotate <irsa-xr-kind> --all crossplane.io/paused-
kubectl annotate <externaldns-xr-kind> --all crossplane.io/paused-
```

### 3.10 Resume Flux Kustomizations (if suspended)

```bash
# If Flux Kustomizations were manually suspended, resume them
flux resume kustomization <your-apps-kustomization> -n flux-system
```

### 3.11 Monitor Recovery

```bash
# Watch Objects sync (count should increase)
watch 'kubectl get object | grep $TARGET | grep -c True'

# Watch ProviderConfig gain users  
watch 'kubectl get providerconfig.kubernetes.crossplane.io $TARGET -o jsonpath="{.status.users}"'

# Watch Flux heal
kubectl get kustomization -n flux-system -w
```

---

## Success Criteria

✅ Kubeconfig test returns nodes successfully (THE KEY TEST)  
✅ ClusterAuth shows Ready=True, Synced=True  
✅ Objects regenerate with today's timestamp (not stale)  
✅ ProviderConfig `status.users` increases to 10+  
✅ IRSA/ExternalDNS compositions show Ready=True, Synced=True  
✅ Flux Kustomizations show Healthy=True  
✅ No InProgress states remain

---

## The Nuclear Option (When Targeted Fixes Fail)

If deleting just ClusterAuth doesn't fix authentication, perform a **complete purge**:

1. Pause ALL compositions (EKS + IRSA + ExternalDNS + others)
2. Delete ALL Objects (clear finalizers first - they never synced)
3. Delete ALL Releases (clear finalizers first)
4. Delete ALL ProviderConfigUsages
5. Delete ALL Usages for this cluster (except Cluster protection)
6. Delete ALL AccessPolicyAssociations  
7. Delete ClusterAuth
8. Unpause EKS XR → everything regenerates fresh
9. Verify kubeconfig works
10. Unpause dependents

This works when comparison debugging shows identical config between broken and working clusters. Sometimes the only fix is full regeneration.

---

## Key Insights

### Why AccessEntry shows Ready but doesn't work
AWS successfully creates the AccessEntry resource, so Kubernetes shows Ready=True. But the IAM principal ARN might be **wrong** (non-existent role, wrong account). The generated kubeconfig can't authenticate.

### Why ProviderConfig shows zero users
Crossplane tries to use the kubeconfig. Authentication fails. Managed resources never successfully connect, so they never become "users".

### Why pausing is necessary
Composition continuously reconciles. If you delete ProviderConfig while active, it recreates immediately with the same broken config. Pausing stops the loop.

---

## Related Skills

- [flux-operator](../flux-operator/SKILL.md): `/flux-status` detects the initial problem
- [oidc-kubeconfig-setup](../oidc-kubeconfig-setup/SKILL.md): Manual OIDC/AccessEntry validation

## Candidates for Observe Mode

Resources that should be protected with `managementPolicy: Observe` to prevent accidental deletion:

| Resource | Why Protect? |
|----------|-------------|
| `Cluster` | The actual EKS cluster - deletion is catastrophic |
| `AccessEntry` | IAM access - deletion breaks authentication |
| `AccessPolicyAssociation` | Policy bindings - deletion removes permissions |
| `ClusterAuth` | Token generation - deletion breaks kubeconfig |

These are the resources where accidental deletion (via bad rollback, garbage collection race, or operator error) would cause significant operational impact.

---

## Reference: AWS Blueprints

For building EKS compositions from scratch, consider:
- [EKS Blueprints for CDK with Auto Mode](https://aws.amazon.com/blogs/containers/amazon-eks-blueprints-for-cdk-now-supporting-amazon-eks-auto-mode/)
- EKS AccessEntry and AccessPolicyAssociation for OIDC-based cluster authentication

## Crossplane v2 Note

Namespace collision and duplicate ProviderConfig issues will be resolved in Crossplane v2 Functions. Until migration, this surgery skill enables manual intervention.
