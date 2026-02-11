#!/bin/bash
# Crossplane Provider Surgery - Diagnostic Script
# 
# Diagnoses connectivity issues for Crossplane Kubernetes/Helm providers
# managing EKS clusters.
#
# Usage: 
#   diagnose.sh TARGET [REFERENCE]
#
# Arguments:
#   TARGET    - Name/pattern of the broken cluster (e.g., "urmanac-prod")
#   REFERENCE - Name/pattern of a working cluster for comparison (optional)
#
# Examples:
#   diagnose.sh prod           # Diagnose prod cluster
#   diagnose.sh prod test      # Compare prod (broken) against test (working)

set -o pipefail

TARGET="${1:-}"
REFERENCE="${2:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
header() { echo -e "\n${BLUE}══════════════════════════════════════════════════════════════${NC}"; echo -e "${BLUE}$1${NC}"; echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}\n"; }

if [ -z "$TARGET" ]; then
    echo "Usage: $0 TARGET [REFERENCE]"
    echo ""
    echo "Arguments:"
    echo "  TARGET    - Name/pattern of the broken cluster (required)"
    echo "  REFERENCE - Name/pattern of a working cluster (optional)"
    echo ""
    echo "Examples:"
    echo "  $0 urmanac-prod"
    echo "  $0 urmanac-prod urmanac-test"
    exit 1
fi

header "Crossplane Provider Surgery - Diagnostic Report"
info "Target cluster pattern: $TARGET"
[ -n "$REFERENCE" ] && info "Reference cluster pattern: $REFERENCE"
echo ""

# ============================================================
# Phase 1: ProviderConfig Health Check
# ============================================================
header "Phase 1: ProviderConfig Health Check"

info "Checking Kubernetes ProviderConfigs..."
echo ""
kubectl get providerconfig.kubernetes.crossplane.io -o json 2>/dev/null | \
    jq -r '.items[] | "\(.metadata.name): \(.status.users // 0) users"' | \
    sort -t: -k2 -n | while read line; do
        name=$(echo "$line" | cut -d: -f1)
        users=$(echo "$line" | grep -oE '[0-9]+ users' | cut -d' ' -f1)
        if [ "$users" -lt 3 ]; then
            echo -e "  ${RED}✗${NC} $line"
        elif [ "$users" -lt 8 ]; then
            echo -e "  ${YELLOW}△${NC} $line"
        else
            echo -e "  ${GREEN}✓${NC} $line"
        fi
    done

echo ""
info "Checking Helm ProviderConfigs..."
echo ""
kubectl get providerconfig.helm.crossplane.io -o json 2>/dev/null | \
    jq -r '.items[] | "\(.metadata.name): \(.status.users // 0) users"' | \
    sort -t: -k2 -n | while read line; do
        name=$(echo "$line" | cut -d: -f1)
        users=$(echo "$line" | grep -oE '[0-9]+ users' | cut -d' ' -f1)
        if [ "$users" -lt 3 ]; then
            echo -e "  ${RED}✗${NC} $line"
        elif [ "$users" -lt 8 ]; then
            echo -e "  ${YELLOW}△${NC} $line"
        else
            echo -e "  ${GREEN}✓${NC} $line"
        fi
    done

# ============================================================
# Phase 2: Target Cluster Deep Dive
# ============================================================
header "Phase 2: Target Cluster Deep Dive - $TARGET"

# Find ProviderConfig for target
info "Finding ProviderConfig for pattern: $TARGET"
TARGET_PC=$(kubectl get providerconfig.kubernetes.crossplane.io -o json 2>/dev/null | \
    jq -r '.items[] | select(.metadata.name | contains("'"$TARGET"'")) | .metadata.name' | head -1)

if [ -z "$TARGET_PC" ]; then
    error "No Kubernetes ProviderConfig found matching pattern: $TARGET"
    echo ""
    info "Available ProviderConfigs:"
    kubectl get providerconfig.kubernetes.crossplane.io -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sed 's/^/  /'
    exit 1
fi

success "Found ProviderConfig: $TARGET_PC"

# Get user count
USERS=$(kubectl get providerconfig.kubernetes.crossplane.io "$TARGET_PC" -o jsonpath='{.status.users}' 2>/dev/null)
if [ "$USERS" -lt 5 ]; then
    warn "Low user count: $USERS (expected 8-20+)"
else
    success "User count: $USERS"
fi

# Get secret reference
info "Checking kubeconfig secret..."
SECRET=$(kubectl get providerconfig.kubernetes.crossplane.io "$TARGET_PC" \
    -o jsonpath='{.spec.credentials.secretRef.name}' 2>/dev/null)
SECRET_NS=$(kubectl get providerconfig.kubernetes.crossplane.io "$TARGET_PC" \
    -o jsonpath='{.spec.credentials.secretRef.namespace}' 2>/dev/null)
SECRET_NS="${SECRET_NS:-crossplane-system}"

if [ -z "$SECRET" ]; then
    error "No secret reference found in ProviderConfig"
else
    if kubectl get secret -n "$SECRET_NS" "$SECRET" &>/dev/null; then
        success "Secret exists: $SECRET_NS/$SECRET"
    else
        error "Secret not found: $SECRET_NS/$SECRET"
    fi
fi

# ============================================================
# Phase 3: Kubeconfig Connectivity Test (THE KEY TEST)
# ============================================================
header "Phase 3: Kubeconfig Connectivity Test"

if [ -n "$SECRET" ]; then
    info "Extracting and testing kubeconfig..."
    TEMP_KC=$(mktemp)
    
    if kubectl get secret -n "$SECRET_NS" "$SECRET" -o jsonpath='{.data.kubeconfig}' 2>/dev/null | base64 -d > "$TEMP_KC" 2>/dev/null; then
        # Test 1: Get nodes
        info "Test 1: kubectl get nodes"
        if KUBECONFIG="$TEMP_KC" kubectl get nodes --request-timeout=10s &>/dev/null; then
            success "✓ Can list nodes"
        else
            error "✗ Cannot list nodes - authentication/connectivity failure"
        fi
        
        # Test 2: Auth check
        info "Test 2: kubectl auth can-i"
        if KUBECONFIG="$TEMP_KC" kubectl auth can-i '*' '*' --all-namespaces --request-timeout=10s &>/dev/null; then
            success "✓ Has cluster-admin permissions"
        else
            warn "△ Limited permissions or auth failure"
        fi
        
        # Test 3: Get server version
        info "Test 3: kubectl version (server)"
        if KUBECONFIG="$TEMP_KC" kubectl version --short 2>/dev/null | grep -q Server; then
            success "✓ Can reach API server"
        else
            error "✗ Cannot reach API server"
        fi
    else
        error "Failed to extract kubeconfig from secret"
    fi
    
    rm -f "$TEMP_KC"
else
    warn "Skipping connectivity test - no secret found"
fi

# ============================================================
# Phase 4: ClusterAuth and AccessEntry Investigation
# ============================================================
header "Phase 4: ClusterAuth and AccessEntry Investigation"

info "Finding ClusterAuth for pattern: $TARGET"
CLUSTER_AUTH=$(kubectl get clusterauth.eks.aws.upbound.io -o json 2>/dev/null | \
    jq -r '.items[] | select(.metadata.name | contains("'"$TARGET"'")) | .metadata.name' | head -1)

if [ -n "$CLUSTER_AUTH" ]; then
    success "Found ClusterAuth: $CLUSTER_AUTH"
    
    # Check status
    CA_READY=$(kubectl get clusterauth.eks.aws.upbound.io "$CLUSTER_AUTH" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    CA_SYNCED=$(kubectl get clusterauth.eks.aws.upbound.io "$CLUSTER_AUTH" \
        -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}' 2>/dev/null)
    
    [ "$CA_READY" = "True" ] && success "Ready: True" || warn "Ready: $CA_READY"
    [ "$CA_SYNCED" = "True" ] && success "Synced: True" || warn "Synced: $CA_SYNCED"
else
    warn "No ClusterAuth found matching pattern: $TARGET"
fi

info "Finding AccessEntry for pattern: $TARGET"
ACCESS_ENTRIES=$(kubectl get accessentry.eks.aws.upbound.io -o json 2>/dev/null | \
    jq -r '.items[] | select(.metadata.name | contains("'"$TARGET"'")) | 
    {name: .metadata.name, arn: .spec.forProvider.principalArn, ready: (.status.conditions[]? | select(.type=="Ready") | .status)}')

if [ -n "$ACCESS_ENTRIES" ]; then
    echo "$ACCESS_ENTRIES" | jq -r '"  AccessEntry: \(.name)\n    Principal ARN: \(.arn)\n    Ready: \(.ready)"'
else
    warn "No AccessEntry found matching pattern: $TARGET"
fi

# ============================================================
# Phase 5: Reference Comparison (if provided)
# ============================================================
if [ -n "$REFERENCE" ]; then
    header "Phase 5: Reference Comparison - $REFERENCE vs $TARGET"
    
    # Compare AccessEntry ARNs
    info "Comparing IAM Principal ARNs (should be IDENTICAL for same-account clusters)..."
    echo ""
    
    TARGET_ARN=$(kubectl get accessentry.eks.aws.upbound.io -o json 2>/dev/null | \
        jq -r '.items[] | select(.metadata.name | contains("'"$TARGET"'")) | .spec.forProvider.principalArn' | head -1)
    REF_ARN=$(kubectl get accessentry.eks.aws.upbound.io -o json 2>/dev/null | \
        jq -r '.items[] | select(.metadata.name | contains("'"$REFERENCE"'")) | .spec.forProvider.principalArn' | head -1)
    
    echo "  Target ($TARGET):    $TARGET_ARN"
    echo "  Reference ($REFERENCE): $REF_ARN"
    echo ""
    
    if [ "$TARGET_ARN" = "$REF_ARN" ]; then
        success "ARNs match - IAM configuration is consistent"
    else
        error "ARN MISMATCH - This is likely the root cause!"
        warn "IAM is not regional - same-account clusters MUST have identical role ARNs"
    fi
    
    # Compare ProviderConfig user counts
    info "Comparing ProviderConfig user counts..."
    echo ""
    
    TARGET_USERS=$(kubectl get providerconfig.kubernetes.crossplane.io -o json 2>/dev/null | \
        jq -r '.items[] | select(.metadata.name | contains("'"$TARGET"'")) | .status.users // 0' | head -1)
    REF_USERS=$(kubectl get providerconfig.kubernetes.crossplane.io -o json 2>/dev/null | \
        jq -r '.items[] | select(.metadata.name | contains("'"$REFERENCE"'")) | .status.users // 0' | head -1)
    
    echo "  Target ($TARGET):    $TARGET_USERS users"
    echo "  Reference ($REFERENCE): $REF_USERS users"
    
    if [ "$REF_USERS" -gt 5 ] && [ "$TARGET_USERS" -lt 3 ]; then
        warn "Reference is healthy, target is broken - surgical intervention recommended"
    fi
fi

# ============================================================
# Summary
# ============================================================
header "Diagnostic Summary"

echo "Target: $TARGET"
echo "ProviderConfig: ${TARGET_PC:-NOT FOUND}"
echo "Users: ${USERS:-0}"
echo "ClusterAuth: ${CLUSTER_AUTH:-NOT FOUND}"
echo ""

# Determine overall status
if [ "${USERS:-0}" -lt 3 ]; then
    error "DIAGNOSIS: Provider appears broken (low/zero users)"
    echo ""
    info "Recommended action: Run /crossplane-surgery for guided repair"
    echo ""
    info "Quick reference - deletion order:"
    echo "  1. Pause all compositions"
    echo "  2. Delete Objects (clear finalizers)"
    echo "  3. Delete Releases (clear finalizers)"
    echo "  4. Delete ProviderConfigUsages"
    echo "  5. Delete Usages"
    echo "  6. Delete AccessPolicyAssociations"
    echo "  7. Delete ClusterAuth"
    echo "  8. Unpause EKS composition"
    echo "  9. Verify kubeconfig"
    echo "  10. Unpause dependents"
elif [ "${USERS:-0}" -lt 8 ]; then
    warn "DIAGNOSIS: Provider may be partially degraded"
    echo ""
    info "Monitor for further degradation or investigate stuck resources"
else
    success "DIAGNOSIS: Provider appears healthy"
fi

echo ""
