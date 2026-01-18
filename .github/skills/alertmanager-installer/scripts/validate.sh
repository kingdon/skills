#!/bin/bash

###########################################
# Part of Kingdon Skills - alertmanager-installer
###########################################
# AlertManager Installer Validation Script
# Validates prerequisites and AlertManager installation health
# Expected ports: Prometheus 9090, AlertManager 9093

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
ALERTMANAGER_URL="${ALERTMANAGER_URL:-http://localhost:9093}"

echo "=== AlertManager Installer Validation ==="
echo ""

# Step 1: Check kubectl connectivity
echo "Step 1: Checking Kubernetes connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo "  Run: kubectl cluster-info to diagnose"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes cluster accessible${NC}"

# Step 2: Check monitoring namespace exists
echo ""
echo "Step 2: Checking monitoring namespace..."
if ! kubectl get namespace monitoring &>/dev/null; then
    echo -e "${YELLOW}⚠ Monitoring namespace does not exist${NC}"
    echo "  Create with: kubectl create namespace monitoring"
    NS_EXISTS=false
else
    echo -e "${GREEN}✓ Monitoring namespace exists${NC}"
    NS_EXISTS=true
fi

# Step 3: Check RBAC permissions
echo ""
echo "Step 3: Checking RBAC permissions..."
CAN_CREATE_AM=$(kubectl auth can-i create alertmanagers.monitoring.coreos.com 2>/dev/null || echo "no")
CAN_CREATE_SM=$(kubectl auth can-i create servicemonitors.monitoring.coreos.com 2>/dev/null || echo "no")

if [ "$CAN_CREATE_AM" = "yes" ]; then
    echo -e "${GREEN}✓ Can create AlertManager resources${NC}"
else
    echo -e "${YELLOW}⚠ Cannot create AlertManager CRDs (may need Prometheus Operator first)${NC}"
fi

if [ "$CAN_CREATE_SM" = "yes" ]; then
    echo -e "${GREEN}✓ Can create ServiceMonitor resources${NC}"
else
    echo -e "${YELLOW}⚠ Cannot create ServiceMonitor CRDs (may need Prometheus Operator first)${NC}"
fi

# Step 4: Check Prometheus Operator is installed
echo ""
echo "Step 4: Checking Prometheus Operator..."
if kubectl get crd prometheuses.monitoring.coreos.com &>/dev/null; then
    echo -e "${GREEN}✓ Prometheus Operator CRDs installed${NC}"
    OPERATOR_INSTALLED=true
else
    echo -e "${RED}✗ Prometheus Operator CRDs not found${NC}"
    echo "  Install kube-prometheus-stack first"
    OPERATOR_INSTALLED=false
fi

# Step 5: Check Prometheus is running
echo ""
echo "Step 5: Checking Prometheus pods..."
if [ "$NS_EXISTS" = true ]; then
    PROM_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | grep -c Running || echo "0")
    if [ "$PROM_PODS" -eq 0 ]; then
        echo -e "${YELLOW}⚠ No running Prometheus pods found${NC}"
        PROM_RUNNING=false
    else
        echo -e "${GREEN}✓ Found $PROM_PODS running Prometheus pod(s)${NC}"
        PROM_RUNNING=true
    fi
else
    echo -e "${YELLOW}⚠ Skipped - monitoring namespace does not exist${NC}"
    PROM_RUNNING=false
fi

# Step 6: Check AlertManager pods
echo ""
echo "Step 6: Checking AlertManager pods..."
if [ "$NS_EXISTS" = true ]; then
    AM_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager --no-headers 2>/dev/null | grep -c Running || echo "0")
    if [ "$AM_PODS" -eq 0 ]; then
        echo -e "${YELLOW}⚠ No running AlertManager pods found${NC}"
        AM_RUNNING=false
    else
        echo -e "${GREEN}✓ Found $AM_PODS running AlertManager pod(s)${NC}"
        AM_RUNNING=true
    fi
else
    echo -e "${YELLOW}⚠ Skipped - monitoring namespace does not exist${NC}"
    AM_RUNNING=false
fi

# Step 7: Check AlertManager API health (via port-forward)
echo ""
echo "Step 7: Checking AlertManager API health..."
if curl -s --connect-timeout 5 "${ALERTMANAGER_URL}/-/healthy" &>/dev/null; then
    echo -e "${GREEN}✓ AlertManager API healthy at ${ALERTMANAGER_URL}${NC}"
    AM_HEALTHY=true
else
    echo -e "${YELLOW}⚠ Cannot reach AlertManager at ${ALERTMANAGER_URL}${NC}"
    echo "  Start port-forward with:"
    echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093 &"
    AM_HEALTHY=false
fi

# Step 8: Check Prometheus → AlertManager connectivity
echo ""
echo "Step 8: Checking Prometheus → AlertManager integration..."
if curl -s --connect-timeout 5 "${PROMETHEUS_URL}/-/healthy" &>/dev/null; then
    AM_UP=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=alertmanager_up" 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    if [ "$AM_UP" = "1" ]; then
        echo -e "${GREEN}✓ Prometheus can reach AlertManager${NC}"
    else
        echo -e "${YELLOW}⚠ Prometheus cannot reach AlertManager (alertmanager_up != 1)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Skipped - Prometheus not reachable at ${PROMETHEUS_URL}${NC}"
    echo "  Start port-forward with:"
    echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &"
fi

# Step 9: Check AlertManager configuration
echo ""
echo "Step 9: Checking AlertManager configuration..."
if [ "$AM_HEALTHY" = true ]; then
    AM_STATUS=$(curl -s "${ALERTMANAGER_URL}/api/v1/status" 2>/dev/null)
    CLUSTER_STATUS=$(echo "$AM_STATUS" | jq -r '.data.clusterStatus.status' 2>/dev/null || echo "unknown")
    UPTIME=$(echo "$AM_STATUS" | jq -r '.data.uptime' 2>/dev/null || echo "unknown")
    
    echo -e "${GREEN}✓ Cluster status: $CLUSTER_STATUS${NC}"
    echo "  Uptime: $UPTIME"
    
    # Check receivers
    RECEIVERS=$(curl -s "${ALERTMANAGER_URL}/api/v1/receivers" 2>/dev/null | jq -r '.data[].name' 2>/dev/null | wc -l || echo "0")
    echo "  Configured receivers: $RECEIVERS"
else
    echo -e "${YELLOW}⚠ Skipped - AlertManager not reachable${NC}"
fi

# Summary
echo ""
echo "=== Summary ==="
if [ "$OPERATOR_INSTALLED" = true ] && [ "$AM_RUNNING" = true ] && [ "$AM_HEALTHY" = true ]; then
    echo -e "${GREEN}✓ AlertManager installation validated successfully${NC}"
    exit 0
elif [ "$OPERATOR_INSTALLED" = true ] && [ "$AM_RUNNING" = true ]; then
    echo -e "${YELLOW}⚠ AlertManager running but API not accessible (start port-forward)${NC}"
    exit 0
elif [ "$OPERATOR_INSTALLED" = true ]; then
    echo -e "${YELLOW}⚠ Prometheus Operator ready, AlertManager not running${NC}"
    echo "  Ready to install AlertManager"
    exit 0
else
    echo -e "${RED}✗ Prerequisites not met - install Prometheus Operator first${NC}"
    exit 1
fi
