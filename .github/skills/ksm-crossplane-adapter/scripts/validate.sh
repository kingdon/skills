#!/bin/bash

###########################################
# Part of Kingdon Skills - ksm-crossplane-adapter
###########################################
# KSM Crossplane Adapter Validation Script
# Validates Crossplane provider installation and metric collection
# Expected ports: Prometheus 9090

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

echo "=== KSM Crossplane Adapter Validation ==="
echo ""

# Step 1: Check kubectl connectivity
echo "Step 1: Checking Kubernetes connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo "  Run: kubectl cluster-info to diagnose"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes cluster accessible${NC}"

# Step 2: Check Crossplane is installed
echo ""
echo "Step 2: Checking Crossplane installation..."
if kubectl get crd providers.pkg.crossplane.io &>/dev/null; then
    echo -e "${GREEN}✓ Crossplane CRDs installed${NC}"
    CROSSPLANE_INSTALLED=true
else
    echo -e "${YELLOW}⚠ Crossplane CRDs not found${NC}"
    echo "  Install Crossplane first: https://docs.crossplane.io/latest/software/install/"
    CROSSPLANE_INSTALLED=false
fi

# Step 3: List installed Crossplane providers
echo ""
echo "Step 3: Checking installed Crossplane providers..."
if [ "$CROSSPLANE_INSTALLED" = true ]; then
    PROVIDERS=$(kubectl get providers.pkg.crossplane.io --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$PROVIDERS" -eq 0 ]; then
        echo -e "${YELLOW}⚠ No Crossplane providers installed${NC}"
    else
        echo -e "${GREEN}✓ Found $PROVIDERS Crossplane provider(s):${NC}"
        kubectl get providers.pkg.crossplane.io --no-headers 2>/dev/null | awk '{print "  - " $1 " (" $2 ")"}'
    fi
else
    echo -e "${YELLOW}⚠ Skipped - Crossplane not installed${NC}"
fi

# Step 4: Check kube-state-metrics is running
echo ""
echo "Step 4: Checking kube-state-metrics..."
KSM_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=kube-state-metrics --no-headers 2>/dev/null | grep -c Running || echo "0")
if [ "$KSM_PODS" -eq 0 ]; then
    echo -e "${YELLOW}⚠ No running kube-state-metrics pods found${NC}"
    KSM_RUNNING=false
else
    echo -e "${GREEN}✓ Found $KSM_PODS kube-state-metrics pod(s)${NC}"
    KSM_RUNNING=true
fi

# Step 5: Check for custom resource state config
echo ""
echo "Step 5: Checking KSM custom resource configuration..."
if [ "$KSM_RUNNING" = true ]; then
    # Check if there's a custom config ConfigMap
    KSM_CONFIG=$(kubectl get configmap -n monitoring -l app.kubernetes.io/name=kube-state-metrics --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$KSM_CONFIG" -gt 0 ]; then
        echo -e "${GREEN}✓ Found $KSM_CONFIG KSM configuration(s)${NC}"
    else
        echo -e "${YELLOW}⚠ No KSM custom configurations found${NC}"
    fi
fi

# Step 6: Check Prometheus connectivity
echo ""
echo "Step 6: Checking Prometheus API connectivity..."
if ! curl -s --connect-timeout 5 "${PROMETHEUS_URL}/-/healthy" &>/dev/null; then
    echo -e "${YELLOW}⚠ Cannot reach Prometheus at ${PROMETHEUS_URL}${NC}"
    echo "  Start port-forward with:"
    echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &"
    PROM_HEALTHY=false
else
    echo -e "${GREEN}✓ Prometheus API healthy${NC}"
    PROM_HEALTHY=true
fi

# Step 7: Check for Crossplane metrics in Prometheus
echo ""
echo "Step 7: Checking Crossplane metrics in Prometheus..."
if [ "$PROM_HEALTHY" = true ]; then
    # Check for any crossplane-related metrics
    CROSSPLANE_METRICS=$(curl -s "${PROMETHEUS_URL}/api/v1/label/__name__/values" 2>/dev/null | jq -r '.data[]' 2>/dev/null | grep -i crossplane | wc -l || echo "0")
    
    if [ "$CROSSPLANE_METRICS" -gt 0 ]; then
        echo -e "${GREEN}✓ Found $CROSSPLANE_METRICS Crossplane-related metric(s)${NC}"
        echo "  Sample metrics:"
        curl -s "${PROMETHEUS_URL}/api/v1/label/__name__/values" 2>/dev/null | jq -r '.data[]' 2>/dev/null | grep -i crossplane | head -5 | while read metric; do
            echo "    - $metric"
        done
    else
        echo -e "${YELLOW}⚠ No Crossplane metrics found in Prometheus${NC}"
        echo "  KSM may need custom resource configuration"
    fi
else
    echo -e "${YELLOW}⚠ Skipped - Prometheus not reachable${NC}"
fi

# Step 8: Check for KStatus condition metrics
echo ""
echo "Step 8: Checking KStatus condition metrics..."
if [ "$PROM_HEALTHY" = true ]; then
    # Check for kube_customresource metrics (standard KSM custom resource metrics)
    KSTATUS_METRICS=$(curl -s "${PROMETHEUS_URL}/api/v1/label/__name__/values" 2>/dev/null | jq -r '.data[]' 2>/dev/null | grep -E "kube_customresource|gotk_reconcile" | wc -l || echo "0")
    
    if [ "$KSTATUS_METRICS" -gt 0 ]; then
        echo -e "${GREEN}✓ Found $KSTATUS_METRICS KStatus/Flux condition metric(s)${NC}"
    else
        echo -e "${YELLOW}⚠ No KStatus condition metrics found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Skipped - Prometheus not reachable${NC}"
fi

# Step 9: List Crossplane managed resources
echo ""
echo "Step 9: Checking Crossplane managed resources..."
if [ "$CROSSPLANE_INSTALLED" = true ]; then
    # Find all Crossplane API groups
    CROSSPLANE_APIS=$(kubectl api-resources --no-headers 2>/dev/null | grep "crossplane.io" | wc -l || echo "0")
    
    if [ "$CROSSPLANE_APIS" -gt 0 ]; then
        echo -e "${GREEN}✓ Found $CROSSPLANE_APIS Crossplane API resource types${NC}"
        
        # Count actual managed resources
        MANAGED_RESOURCES=$(kubectl get managed --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$MANAGED_RESOURCES" -gt 0 ]; then
            echo "  Active managed resources: $MANAGED_RESOURCES"
        else
            echo "  No managed resources currently deployed"
        fi
    else
        echo -e "${YELLOW}⚠ No Crossplane API resources found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Skipped - Crossplane not installed${NC}"
fi

# Summary
echo ""
echo "=== Summary ==="
if [ "$CROSSPLANE_INSTALLED" = true ] && [ "$KSM_RUNNING" = true ] && [ "$PROM_HEALTHY" = true ] && [ "$CROSSPLANE_METRICS" -gt 0 ]; then
    echo -e "${GREEN}✓ KSM Crossplane Adapter validation passed${NC}"
    echo "  Crossplane metrics are being collected by Prometheus"
    exit 0
elif [ "$CROSSPLANE_INSTALLED" = true ] && [ "$KSM_RUNNING" = true ] && [ "$PROM_HEALTHY" = true ]; then
    echo -e "${YELLOW}⚠ Crossplane installed but metrics not configured${NC}"
    echo "  Use resource-template-engine skill to generate metric configurations"
    exit 0
elif [ "$CROSSPLANE_INSTALLED" = true ] && [ "$KSM_RUNNING" = true ]; then
    echo -e "${YELLOW}⚠ KSM running but Prometheus not reachable${NC}"
    echo "  Start port-forward to verify metric collection"
    exit 0
elif [ "$CROSSPLANE_INSTALLED" = true ]; then
    echo -e "${YELLOW}⚠ Crossplane installed, waiting for KSM${NC}"
    exit 0
else
    echo -e "${RED}✗ Prerequisites not met - install Crossplane first${NC}"
    exit 1
fi
