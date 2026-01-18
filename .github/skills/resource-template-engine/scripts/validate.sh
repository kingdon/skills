#!/bin/bash

###########################################
# Part of Kingdon Skills - resource-template-engine
###########################################
# Resource Template Engine Validation Script
# Discovers Crossplane resources and validates template generation
# Expected ports: Prometheus 9090

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

echo "=== Resource Template Engine Validation ==="
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
    CROSSPLANE_INSTALLED=false
fi

# Step 3: Discover Crossplane resource types
echo ""
echo "Step 3: Discovering Crossplane resource types..."
if [ "$CROSSPLANE_INSTALLED" = true ]; then
    # Find all Crossplane API groups
    echo -e "${BLUE}Crossplane API groups:${NC}"
    
    # Database resources
    DB_RESOURCES=$(kubectl api-resources --no-headers 2>/dev/null | grep -iE "crossplane.io.*(sql|db|database|redis|mongo|postgres|mysql)" | wc -l || echo "0")
    echo "  Database resources: $DB_RESOURCES"
    
    # Network resources
    NET_RESOURCES=$(kubectl api-resources --no-headers 2>/dev/null | grep -iE "crossplane.io.*(vpc|subnet|security|route|gateway|lb|loadbalancer)" | wc -l || echo "0")
    echo "  Network resources: $NET_RESOURCES"
    
    # Compute resources
    COMPUTE_RESOURCES=$(kubectl api-resources --no-headers 2>/dev/null | grep -iE "crossplane.io.*(instance|cluster|node|vm|compute)" | wc -l || echo "0")
    echo "  Compute resources: $COMPUTE_RESOURCES"
    
    # Storage resources
    STORAGE_RESOURCES=$(kubectl api-resources --no-headers 2>/dev/null | grep -iE "crossplane.io.*(bucket|disk|volume|blob|storage)" | wc -l || echo "0")
    echo "  Storage resources: $STORAGE_RESOURCES"
    
    TOTAL_RESOURCES=$((DB_RESOURCES + NET_RESOURCES + COMPUTE_RESOURCES + STORAGE_RESOURCES))
    echo ""
    echo -e "${GREEN}✓ Total categorizable resources: $TOTAL_RESOURCES${NC}"
else
    echo -e "${YELLOW}⚠ Skipped - Crossplane not installed${NC}"
fi

# Step 4: Check for existing KSM configurations
echo ""
echo "Step 4: Checking existing KSM configurations..."
KSM_CONFIGS=$(kubectl get configmap -n monitoring --no-headers 2>/dev/null | grep -i "ksm\|kube-state-metrics" | wc -l || echo "0")
if [ "$KSM_CONFIGS" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $KSM_CONFIGS KSM configuration(s)${NC}"
    kubectl get configmap -n monitoring --no-headers 2>/dev/null | grep -i "ksm\|kube-state-metrics" | awk '{print "  - " $1}'
else
    echo -e "${YELLOW}⚠ No KSM configurations found${NC}"
fi

# Step 5: Check for existing PrometheusRules
echo ""
echo "Step 5: Checking existing Crossplane alert rules..."
PROM_RULES=$(kubectl get prometheusrule -n monitoring --no-headers 2>/dev/null | grep -i crossplane | wc -l || echo "0")
if [ "$PROM_RULES" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $PROM_RULES Crossplane PrometheusRule(s)${NC}"
    kubectl get prometheusrule -n monitoring --no-headers 2>/dev/null | grep -i crossplane | awk '{print "  - " $1}'
else
    echo -e "${YELLOW}⚠ No Crossplane PrometheusRules found${NC}"
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

# Step 7: Identify resources needing templates
echo ""
echo "Step 7: Identifying resources needing metric templates..."
if [ "$CROSSPLANE_INSTALLED" = true ] && [ "$PROM_HEALTHY" = true ]; then
    # Get all Crossplane managed resources
    MANAGED_TYPES=$(kubectl api-resources --no-headers 2>/dev/null | grep "crossplane.io" | awk '{print $1}' | head -20)
    
    NEEDS_TEMPLATE=0
    HAS_METRICS=0
    
    for resource_type in $MANAGED_TYPES; do
        # Check if metrics exist for this resource type
        METRIC_NAME="crossplane_$(echo $resource_type | tr '[:upper:]' '[:lower:]' | tr '-' '_')"
        METRIC_EXISTS=$(curl -s "${PROMETHEUS_URL}/api/v1/label/__name__/values" 2>/dev/null | jq -r '.data[]' 2>/dev/null | grep -i "$METRIC_NAME" | wc -l || echo "0")
        
        if [ "$METRIC_EXISTS" -gt 0 ]; then
            HAS_METRICS=$((HAS_METRICS + 1))
        else
            NEEDS_TEMPLATE=$((NEEDS_TEMPLATE + 1))
        fi
    done
    
    echo -e "${GREEN}✓ Resources with metrics: $HAS_METRICS${NC}"
    echo -e "${YELLOW}⚠ Resources needing templates: $NEEDS_TEMPLATE${NC}"
else
    echo -e "${YELLOW}⚠ Skipped - prerequisites not met${NC}"
fi

# Step 8: Validate template directory structure
echo ""
echo "Step 8: Checking template directory structure..."
SKILL_DIR=".github/skills/resource-template-engine"
if [ -d "$SKILL_DIR" ]; then
    echo -e "${GREEN}✓ Skill directory exists${NC}"
    
    if [ -d "$SKILL_DIR/templates" ]; then
        TEMPLATE_COUNT=$(ls -1 "$SKILL_DIR/templates"/*.yaml 2>/dev/null | wc -l || echo "0")
        echo "  Template files: $TEMPLATE_COUNT"
    else
        echo -e "${YELLOW}⚠ No templates directory (optional)${NC}"
    fi
    
    if [ -d "$SKILL_DIR/scripts" ]; then
        SCRIPT_COUNT=$(ls -1 "$SKILL_DIR/scripts"/*.sh 2>/dev/null | wc -l || echo "0")
        echo "  Script files: $SCRIPT_COUNT"
    fi
else
    echo -e "${YELLOW}⚠ Skill directory not found${NC}"
fi

# Summary
echo ""
echo "=== Summary ==="
if [ "$CROSSPLANE_INSTALLED" = true ] && [ "$PROM_HEALTHY" = true ]; then
    echo -e "${GREEN}✓ Resource Template Engine ready${NC}"
    echo "  Crossplane resource types discovered"
    echo "  Ready to generate metric configurations and alert rules"
    exit 0
elif [ "$CROSSPLANE_INSTALLED" = true ]; then
    echo -e "${YELLOW}⚠ Crossplane installed, Prometheus not reachable${NC}"
    echo "  Start port-forward to verify metric collection"
    exit 0
else
    echo -e "${YELLOW}⚠ Crossplane not installed - template engine on standby${NC}"
    echo "  Install Crossplane to enable resource templating"
    exit 0
fi
