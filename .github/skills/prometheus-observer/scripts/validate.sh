#!/bin/bash

###########################################
# Part of Kingdon Skills - prometheus-observer
###########################################
# Prometheus Observer Validation Script
# Checks Prometheus and AlertManager health via port-forwarded endpoints
# Expected ports: Prometheus 9090, AlertManager 9093

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
ALERTMANAGER_URL="${ALERTMANAGER_URL:-http://localhost:9093}"

echo "=== Prometheus Observer Validation ==="
echo ""

# Step 1: Check kubectl connectivity
echo "Step 1: Checking Kubernetes connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    echo "  Run: kubectl cluster-info to diagnose"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes cluster accessible${NC}"

# Step 2: Check Prometheus pod exists
echo ""
echo "Step 2: Checking Prometheus pods..."
PROM_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | wc -l)
if [ "$PROM_PODS" -eq 0 ]; then
    echo -e "${RED}✗ No Prometheus pods found in monitoring namespace${NC}"
    echo "  Run: kubectl get pods -n monitoring"
    exit 1
fi
echo -e "${GREEN}✓ Found $PROM_PODS Prometheus pod(s)${NC}"

# Step 3: Check AlertManager pod exists
echo ""
echo "Step 3: Checking AlertManager pods..."
AM_PODS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager --no-headers 2>/dev/null | wc -l)
if [ "$AM_PODS" -eq 0 ]; then
    echo -e "${YELLOW}⚠ No AlertManager pods found (optional)${NC}"
else
    echo -e "${GREEN}✓ Found $AM_PODS AlertManager pod(s)${NC}"
fi

# Step 4: Check port-forward connectivity to Prometheus
echo ""
echo "Step 4: Checking Prometheus API connectivity..."
if ! curl -s --connect-timeout 5 "${PROMETHEUS_URL}/-/healthy" &>/dev/null; then
    echo -e "${YELLOW}⚠ Cannot reach Prometheus at ${PROMETHEUS_URL}${NC}"
    echo "  Start port-forward with:"
    echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &"
    PROM_HEALTHY=false
else
    echo -e "${GREEN}✓ Prometheus API healthy${NC}"
    PROM_HEALTHY=true
fi

# Step 5: Check port-forward connectivity to AlertManager
echo ""
echo "Step 5: Checking AlertManager API connectivity..."
if ! curl -s --connect-timeout 5 "${ALERTMANAGER_URL}/-/healthy" &>/dev/null; then
    echo -e "${YELLOW}⚠ Cannot reach AlertManager at ${ALERTMANAGER_URL}${NC}"
    echo "  Start port-forward with:"
    echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093 &"
    AM_HEALTHY=false
else
    echo -e "${GREEN}✓ AlertManager API healthy${NC}"
    AM_HEALTHY=true
fi

# Step 6: Query active alerts if Prometheus is reachable
echo ""
echo "Step 6: Querying active alerts..."
if [ "$PROM_HEALTHY" = true ]; then
    ALERTS=$(curl -s "${PROMETHEUS_URL}/api/v1/alerts" 2>/dev/null)
    ALERT_COUNT=$(echo "$ALERTS" | jq -r '.data.alerts | length' 2>/dev/null || echo "0")
    FIRING_COUNT=$(echo "$ALERTS" | jq -r '[.data.alerts[] | select(.state=="firing")] | length' 2>/dev/null || echo "0")
    
    echo -e "${GREEN}✓ Total alerts: $ALERT_COUNT (firing: $FIRING_COUNT)${NC}"
    
    # List firing alerts
    if [ "$FIRING_COUNT" -gt 0 ]; then
        echo ""
        echo "Firing alerts:"
        echo "$ALERTS" | jq -r '.data.alerts[] | select(.state=="firing") | "  - \(.labels.alertname) (\(.labels.severity // "unknown"))"' 2>/dev/null
    fi
else
    echo -e "${YELLOW}⚠ Skipped - Prometheus not reachable${NC}"
fi

# Step 7: Check scrape targets health
echo ""
echo "Step 7: Checking scrape target health..."
if [ "$PROM_HEALTHY" = true ]; then
    TARGETS=$(curl -s "${PROMETHEUS_URL}/api/v1/targets" 2>/dev/null)
    UP_COUNT=$(echo "$TARGETS" | jq -r '[.data.activeTargets[] | select(.health=="up")] | length' 2>/dev/null || echo "0")
    DOWN_COUNT=$(echo "$TARGETS" | jq -r '[.data.activeTargets[] | select(.health!="up")] | length' 2>/dev/null || echo "0")
    
    echo -e "${GREEN}✓ Targets up: $UP_COUNT, down: $DOWN_COUNT${NC}"
    
    if [ "$DOWN_COUNT" -gt 0 ]; then
        echo ""
        echo "Down targets:"
        echo "$TARGETS" | jq -r '.data.activeTargets[] | select(.health!="up") | "  - \(.labels.job): \(.scrapeUrl)"' 2>/dev/null
    fi
else
    echo -e "${YELLOW}⚠ Skipped - Prometheus not reachable${NC}"
fi

# Summary
echo ""
echo "=== Summary ==="
if [ "$PROM_HEALTHY" = true ] && [ "$AM_HEALTHY" = true ]; then
    echo -e "${GREEN}✓ Prometheus Observer validation passed${NC}"
    exit 0
elif [ "$PROM_HEALTHY" = true ]; then
    echo -e "${YELLOW}⚠ Prometheus healthy, AlertManager unreachable${NC}"
    exit 0
else
    echo -e "${RED}✗ Prometheus not reachable - start port-forward${NC}"
    exit 1
fi
