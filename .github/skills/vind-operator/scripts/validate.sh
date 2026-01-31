#!/bin/bash

###########################################
# Part of Kingdon Skills - vind-operator
###########################################
# Validates Vind cluster health and cross-architecture readiness

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Vind Cluster Validation ===${NC}"
echo "Time: $(date)"
echo ""

WARNINGS=0
FAILURES=0

# Step 1: Check if vind is installed
echo -e "${BLUE}Step 1: Checking Vind installation...${NC}"
if command -v vind &> /dev/null; then
  VIND_VERSION=$(vind version 2>/dev/null || echo "unknown")
  echo -e "${GREEN}✓ Vind installed: $VIND_VERSION${NC}"
else
  echo -e "${YELLOW}⚠ Vind not installed - falling back to Kind check${NC}"
  if command -v kind &> /dev/null; then
    KIND_VERSION=$(kind version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓ Kind installed: $KIND_VERSION${NC}"
  else
    echo -e "${RED}✗ Neither Vind nor Kind installed${NC}"
    echo "  Install Vind: brew install vind (or follow Vind installation docs)"
    FAILURES=$((FAILURES + 1))
  fi
fi
echo ""

# Step 2: List clusters
echo -e "${BLUE}Step 2: Listing clusters...${NC}"
if command -v vind &> /dev/null; then
  CLUSTERS=$(vind get clusters 2>/dev/null || echo "")
elif command -v kind &> /dev/null; then
  CLUSTERS=$(kind get clusters 2>/dev/null || echo "")
else
  CLUSTERS=""
fi

if [ -n "$CLUSTERS" ]; then
  echo "Active clusters:"
  echo "$CLUSTERS" | while read cluster; do
    echo "  - $cluster"
  done
else
  echo -e "${YELLOW}⚠ No clusters found${NC}"
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Step 3: Check resource usage on first cluster
echo -e "${BLUE}Step 3: Checking cluster resource usage...${NC}"
if kubectl cluster-info > /dev/null 2>&1; then
  # Check node resources if metrics-server available
  if kubectl top nodes > /dev/null 2>&1; then
    echo "Node resource usage:"
    kubectl top nodes
  else
    echo -e "${YELLOW}⚠ Metrics server not available${NC}"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo -e "${YELLOW}⚠ No cluster connected${NC}"
fi
echo ""

# Step 4: Check for resource pressure
echo -e "${BLUE}Step 4: Checking for resource pressure...${NC}"
if kubectl get nodes > /dev/null 2>&1; then
  MEMORY_PRESSURE=$(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="MemoryPressure")].status}' 2>/dev/null || echo "")
  DISK_PRESSURE=$(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="DiskPressure")].status}' 2>/dev/null || echo "")
  
  if echo "$MEMORY_PRESSURE" | grep -q "True"; then
    echo -e "${RED}✗ Memory pressure detected!${NC}"
    FAILURES=$((FAILURES + 1))
  else
    echo -e "${GREEN}✓ No memory pressure${NC}"
  fi
  
  if echo "$DISK_PRESSURE" | grep -q "True"; then
    echo -e "${RED}✗ Disk pressure detected!${NC}"
    FAILURES=$((FAILURES + 1))
  else
    echo -e "${GREEN}✓ No disk pressure${NC}"
  fi
else
  echo -e "${YELLOW}⚠ Cannot check resource pressure${NC}"
fi
echo ""

# Step 5: Check cross-architecture image support
echo -e "${BLUE}Step 5: Cross-architecture readiness...${NC}"
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  echo "Host architecture: x86_64 (amd64)"
  echo -e "${GREEN}✓ Can test ARM64 manifests before deployment${NC}"
elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  echo "Host architecture: ARM64"
  echo -e "${GREEN}✓ Native ARM64 testing available${NC}"
else
  echo "Host architecture: $ARCH"
fi

# Check if docker supports multi-arch
if docker buildx version > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Docker buildx available for multi-arch builds${NC}"
else
  echo -e "${YELLOW}⚠ Docker buildx not available${NC}"
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Summary
echo -e "${BLUE}=== Validation Summary ===${NC}"
if [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo -e "${GREEN}✓ All checks passed${NC}"
  exit 0
elif [ "$FAILURES" -eq 0 ]; then
  echo -e "${YELLOW}⚠ $WARNINGS warning(s), no failures${NC}"
  exit 0
else
  echo -e "${RED}✗ $FAILURES failure(s), $WARNINGS warning(s)${NC}"
  exit 1
fi
