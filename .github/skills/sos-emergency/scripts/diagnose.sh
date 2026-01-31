#!/bin/bash

###########################################
# Part of Kingdon Skills - sos-emergency
###########################################
# Emergency diagnostic script for Sunkworks home lab
# Quickly assesses cluster and infrastructure health

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== SOS Emergency Diagnostics ===${NC}"
echo "Time: $(date)"
echo ""

FAILURES=0

# Step 1: Check kubectl connectivity
echo -e "${BLUE}Step 1: Checking Kubernetes connectivity...${NC}"
if kubectl cluster-info --request-timeout=5s > /dev/null 2>&1; then
  CONTEXT=$(kubectl config current-context)
  echo -e "${GREEN}✓ Connected to cluster: $CONTEXT${NC}"
else
  echo -e "${RED}✗ Cannot reach Kubernetes API server${NC}"
  echo "  Possible causes:"
  echo "  - VPN/Tailscale disconnected"
  echo "  - Control plane down"
  echo "  - kubeconfig misconfigured"
  FAILURES=$((FAILURES + 1))
fi
echo ""

# Step 2: Check node status
echo -e "${BLUE}Step 2: Checking node status...${NC}"
if kubectl get nodes > /dev/null 2>&1; then
  NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready" | wc -l || echo "0")
  TOTAL=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
  
  if [ "$NOT_READY" -gt 0 ]; then
    echo -e "${RED}✗ $NOT_READY of $TOTAL nodes NOT Ready${NC}"
    kubectl get nodes | grep -v " Ready" || true
    FAILURES=$((FAILURES + 1))
  else
    echo -e "${GREEN}✓ All $TOTAL nodes Ready${NC}"
  fi
else
  echo -e "${YELLOW}⚠ Could not retrieve node status${NC}"
fi
echo ""

# Step 3: Check etcd health (Talos only)
echo -e "${BLUE}Step 3: Checking etcd health...${NC}"
if command -v talosctl &> /dev/null; then
  # Try to get etcd status from first available node
  NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
  if [ -n "$NODES" ]; then
    FIRST_NODE=$(echo $NODES | awk '{print $1}')
    if talosctl -n "$FIRST_NODE" etcd status > /dev/null 2>&1; then
      MEMBERS=$(talosctl -n "$FIRST_NODE" etcd members 2>/dev/null | grep -c "started" || echo "0")
      echo -e "${GREEN}✓ etcd healthy with $MEMBERS members${NC}"
    else
      echo -e "${RED}✗ etcd unreachable or unhealthy${NC}"
      FAILURES=$((FAILURES + 1))
    fi
  else
    echo -e "${YELLOW}⚠ No node IPs found for etcd check${NC}"
  fi
else
  echo -e "${YELLOW}⚠ talosctl not installed, skipping etcd check${NC}"
fi
echo ""

# Step 4: Check for failing pods
echo -e "${BLUE}Step 4: Checking for failing pods...${NC}"
if kubectl get pods -A > /dev/null 2>&1; then
  FAILING=$(kubectl get pods -A --no-headers 2>/dev/null | grep -vE "Running|Completed" | wc -l || echo "0")
  if [ "$FAILING" -gt 0 ]; then
    echo -e "${RED}✗ $FAILING pods not in Running/Completed state${NC}"
    kubectl get pods -A --no-headers | grep -vE "Running|Completed" | head -10
    FAILURES=$((FAILURES + 1))
  else
    echo -e "${GREEN}✓ All pods healthy${NC}"
  fi
else
  echo -e "${YELLOW}⚠ Could not retrieve pod status${NC}"
fi
echo ""

# Step 5: Check Flux health
echo -e "${BLUE}Step 5: Checking Flux reconciliation...${NC}"
if kubectl get fluxinstance -n flux-system > /dev/null 2>&1; then
  FLUX_READY=$(kubectl get fluxinstance flux -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
  if [ "$FLUX_READY" = "True" ]; then
    echo -e "${GREEN}✓ Flux reconciliation healthy${NC}"
  else
    echo -e "${RED}✗ Flux not ready: $FLUX_READY${NC}"
    kubectl get fluxinstance flux -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null || true
    echo ""
    FAILURES=$((FAILURES + 1))
  fi
else
  echo -e "${YELLOW}⚠ Flux not installed or unreachable${NC}"
fi
echo ""

# Step 6: Check recent events for errors
echo -e "${BLUE}Step 6: Checking recent error events...${NC}"
ERRORS=$(kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp 2>/dev/null | tail -5 || echo "")
if [ -n "$ERRORS" ] && [ "$(echo "$ERRORS" | wc -l)" -gt 1 ]; then
  echo -e "${YELLOW}⚠ Recent warning events:${NC}"
  echo "$ERRORS"
else
  echo -e "${GREEN}✓ No recent warning events${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}=== Diagnostic Summary ===${NC}"
if [ "$FAILURES" -eq 0 ]; then
  echo -e "${GREEN}✓ All checks passed - cluster appears healthy${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAILURES check(s) failed - investigation needed${NC}"
  echo ""
  echo "Recommended actions:"
  echo "  1. Check network/VPN connectivity"
  echo "  2. Review node logs: talosctl -n <node-ip> dmesg"
  echo "  3. Check etcd status: talosctl -n <node-ip> etcd status"
  echo "  4. Review Flux logs: kubectl logs -n flux-system deployment/kustomize-controller"
  exit 1
fi
