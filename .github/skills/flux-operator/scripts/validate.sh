#!/bin/bash

###########################################
# Part of Kingdon Skills - flux-operator
###########################################
# Validates Flux Operator installation, FluxInstance status,
# GitOps connectivity, and component health.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Flux Operator Validation ==="
echo ""

# Track overall status
WARNINGS=0
ERRORS=0

# Step 1: Check Kubernetes connectivity
echo "Step 1: Checking Kubernetes cluster connectivity..."
if kubectl cluster-info &>/dev/null; then
    CONTEXT=$(kubectl config current-context 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓ Connected to cluster: ${CONTEXT}${NC}"
else
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo "  Please check your KUBECONFIG or cluster access"
    exit 1
fi
echo ""

# Step 2: Check Flux Operator CLI
echo "Step 2: Checking Flux Operator CLI..."
if command -v flux-operator &>/dev/null; then
    VERSION=$(flux-operator version 2>/dev/null | head -3 || echo "unknown")
    echo -e "${GREEN}✓ flux-operator CLI installed${NC}"
    echo "$VERSION" | sed 's/^/  /'
else
    echo -e "${YELLOW}⚠ flux-operator CLI not installed${NC}"
    echo "  Install with: brew install controlplaneio-fluxcd/tap/flux-operator"
    ((WARNINGS++))
fi
echo ""

# Step 3: Check FluxInstance
echo "Step 3: Checking FluxInstance resource..."
if kubectl get fluxinstance -n flux-system flux &>/dev/null; then
    READY=$(kubectl get fluxinstance flux -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    MESSAGE=$(kubectl get fluxinstance flux -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
    REVISION=$(kubectl get fluxinstance flux -n flux-system -o jsonpath='{.status.revision}' 2>/dev/null)
    
    if [ "$READY" == "True" ]; then
        echo -e "${GREEN}✓ FluxInstance 'flux' is Ready${NC}"
        echo "  Message: $MESSAGE"
        echo "  Revision: $REVISION"
    else
        echo -e "${RED}✗ FluxInstance 'flux' is NOT Ready${NC}"
        echo "  Status: $READY"
        echo "  Message: $MESSAGE"
        ((ERRORS++))
    fi
else
    echo -e "${RED}✗ FluxInstance 'flux' not found in flux-system namespace${NC}"
    echo "  Flux Operator may not be installed"
    ((ERRORS++))
fi
echo ""

# Step 4: Check Flux component pods
echo "Step 4: Checking Flux component pods..."
EXPECTED_COMPONENTS=("flux-operator" "source-controller" "kustomize-controller" "helm-controller" "notification-controller")
for COMPONENT in "${EXPECTED_COMPONENTS[@]}"; do
    POD_STATUS=$(kubectl get pods -n flux-system -l app.kubernetes.io/component="$COMPONENT" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
    if [ -z "$POD_STATUS" ]; then
        # Try alternative label selectors
        POD_STATUS=$(kubectl get pods -n flux-system --field-selector=status.phase=Running 2>/dev/null | grep "$COMPONENT" | head -1 | awk '{print $3}' || echo "")
    fi
    
    if [ "$POD_STATUS" == "Running" ]; then
        echo -e "${GREEN}  ✓ $COMPONENT: Running${NC}"
    elif [ -n "$POD_STATUS" ]; then
        echo -e "${YELLOW}  ⚠ $COMPONENT: $POD_STATUS${NC}"
        ((WARNINGS++))
    else
        # Fallback: just grep for component name
        if kubectl get pods -n flux-system 2>/dev/null | grep -q "$COMPONENT"; then
            POD_LINE=$(kubectl get pods -n flux-system 2>/dev/null | grep "$COMPONENT" | head -1)
            POD_PHASE=$(echo "$POD_LINE" | awk '{print $3}')
            if [ "$POD_PHASE" == "Running" ]; then
                echo -e "${GREEN}  ✓ $COMPONENT: Running${NC}"
            else
                echo -e "${YELLOW}  ⚠ $COMPONENT: $POD_PHASE${NC}"
                ((WARNINGS++))
            fi
        else
            echo -e "${YELLOW}  ⚠ $COMPONENT: Not found${NC}"
            ((WARNINGS++))
        fi
    fi
done
echo ""

# Step 5: Check GitRepository
echo "Step 5: Checking GitRepository resources..."
GIT_REPOS=$(kubectl get gitrepository -n flux-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\t"}{.status.conditions[?(@.type=="Ready")].message}{"\n"}{end}' 2>/dev/null)
if [ -n "$GIT_REPOS" ]; then
    while IFS=$'\t' read -r NAME READY MSG; do
        if [ "$READY" == "True" ]; then
            echo -e "${GREEN}  ✓ $NAME: Ready${NC}"
            echo "    $(echo "$MSG" | cut -c1-80)..."
        else
            echo -e "${RED}  ✗ $NAME: Not Ready${NC}"
            echo "    $MSG"
            ((ERRORS++))
        fi
    done <<< "$GIT_REPOS"
else
    echo -e "${YELLOW}  ⚠ No GitRepository resources found${NC}"
    ((WARNINGS++))
fi
echo ""

# Step 6: Check Kustomizations
echo "Step 6: Checking Kustomization resources..."
KUSTOMIZATIONS=$(kubectl get kustomization -n flux-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\t"}{.status.conditions[?(@.type=="Ready")].message}{"\n"}{end}' 2>/dev/null)
if [ -n "$KUSTOMIZATIONS" ]; then
    while IFS=$'\t' read -r NAME READY MSG; do
        if [ "$READY" == "True" ]; then
            echo -e "${GREEN}  ✓ $NAME: Ready${NC}"
        else
            echo -e "${RED}  ✗ $NAME: Not Ready${NC}"
            echo "    $MSG"
            ((ERRORS++))
        fi
    done <<< "$KUSTOMIZATIONS"
else
    echo -e "${YELLOW}  ⚠ No Kustomization resources found${NC}"
    ((WARNINGS++))
fi
echo ""

# Step 7: Check HelmReleases (if any)
echo "Step 7: Checking HelmRelease resources..."
HR_COUNT=$(kubectl get helmrelease -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$HR_COUNT" -gt 0 ]; then
    NOT_READY=$(kubectl get helmrelease -A -o jsonpath='{range .items[?(@.status.conditions[0].status!="True")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null)
    if [ -n "$NOT_READY" ]; then
        echo -e "${YELLOW}  ⚠ HelmReleases not ready:${NC}"
        echo "$NOT_READY" | sed 's/^/    /'
        ((WARNINGS++))
    else
        echo -e "${GREEN}  ✓ All $HR_COUNT HelmRelease(s) are Ready${NC}"
    fi
else
    echo -e "${BLUE}  ℹ No HelmRelease resources deployed${NC}"
fi
echo ""

# Step 8: Check Flux UI availability
echo "Step 8: Checking Flux UI service..."
if kubectl get svc flux-operator -n flux-system &>/dev/null; then
    PORTS=$(kubectl get svc flux-operator -n flux-system -o jsonpath='{.spec.ports[*].port}' 2>/dev/null)
    echo -e "${GREEN}  ✓ Flux Operator service available${NC}"
    echo "    Ports: $PORTS"
    echo ""
    echo "  To access the Flux UI:"
    echo -e "    ${BLUE}kubectl -n flux-system port-forward svc/flux-operator 9080:9080${NC}"
    echo "    Then open: http://localhost:9080"
else
    echo -e "${YELLOW}  ⚠ Flux Operator service not found${NC}"
    ((WARNINGS++))
fi
echo ""

# Step 9: Check MCP Server
echo "Step 9: Checking Flux MCP Server..."
if command -v flux-operator-mcp &>/dev/null; then
    MCP_VERSION=$(flux-operator-mcp version 2>/dev/null || echo "installed")
    echo -e "${GREEN}  ✓ flux-operator-mcp installed${NC}"
    echo "    $MCP_VERSION"
else
    echo -e "${YELLOW}  ⚠ flux-operator-mcp not installed${NC}"
    echo "    Install with: brew install controlplaneio-fluxcd/tap/flux-operator-mcp"
    echo "    This enables AI-powered GitOps with Claude, Copilot, or Cursor"
    ((WARNINGS++))
fi
echo ""

# Step 10: Check for recent errors/events
echo "Step 10: Checking recent events..."
RECENT_WARNINGS=$(kubectl get events -n flux-system --field-selector=type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -5)
if [ -n "$RECENT_WARNINGS" ] && [ "$(echo "$RECENT_WARNINGS" | wc -l)" -gt 1 ]; then
    echo -e "${YELLOW}  ⚠ Recent warning events:${NC}"
    echo "$RECENT_WARNINGS" | tail -3 | sed 's/^/    /'
    ((WARNINGS++))
else
    echo -e "${GREEN}  ✓ No recent warning events${NC}"
fi
echo ""

# Summary
echo "=== Summary ==="
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠ Validation passed with $WARNINGS warning(s)${NC}"
    exit 0
else
    echo -e "${GREEN}✓ All checks passed - GitOps is connected and healthy${NC}"
    exit 0
fi
