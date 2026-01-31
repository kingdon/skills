#!/bin/bash

###########################################
# Part of Kingdon Skills - postmortem-author
###########################################
# Collects timeline data from Kubernetes events for post-mortem analysis

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default to last 4 hours
HOURS_AGO=${1:-4}

echo -e "${BLUE}=== Post-Mortem Timeline Collection ===${NC}"
echo "Collecting events from last $HOURS_AGO hours..."
echo "Time: $(date)"
echo ""

OUTPUT_DIR="${OUTPUT_DIR:-/tmp/postmortem-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUTPUT_DIR"

# Step 1: Collect Kubernetes events
echo -e "${BLUE}Step 1: Collecting Kubernetes events...${NC}"
if kubectl get events -A > /dev/null 2>&1; then
  kubectl get events -A --sort-by=.lastTimestamp -o wide > "$OUTPUT_DIR/events.txt" 2>&1
  EVENT_COUNT=$(wc -l < "$OUTPUT_DIR/events.txt")
  echo -e "${GREEN}✓ Collected $EVENT_COUNT events${NC}"
else
  echo -e "${YELLOW}⚠ Could not collect Kubernetes events${NC}"
fi
echo ""

# Step 2: Collect Flux reconciliation status
echo -e "${BLUE}Step 2: Collecting Flux status...${NC}"
if kubectl get fluxinstance -n flux-system > /dev/null 2>&1; then
  {
    echo "=== FluxInstance Status ==="
    kubectl get fluxinstance -n flux-system -o yaml
    echo ""
    echo "=== Kustomizations ==="
    kubectl get kustomization -A -o wide
    echo ""
    echo "=== HelmReleases ==="
    kubectl get helmrelease -A -o wide
    echo ""
    echo "=== GitRepositories ==="
    kubectl get gitrepository -A -o wide
  } > "$OUTPUT_DIR/flux-status.txt" 2>&1
  echo -e "${GREEN}✓ Collected Flux status${NC}"
else
  echo -e "${YELLOW}⚠ Flux not available${NC}"
fi
echo ""

# Step 3: Collect node status
echo -e "${BLUE}Step 3: Collecting node status...${NC}"
if kubectl get nodes > /dev/null 2>&1; then
  kubectl get nodes -o wide > "$OUTPUT_DIR/nodes.txt" 2>&1
  kubectl describe nodes > "$OUTPUT_DIR/nodes-describe.txt" 2>&1
  echo -e "${GREEN}✓ Collected node status${NC}"
else
  echo -e "${YELLOW}⚠ Could not collect node status${NC}"
fi
echo ""

# Step 4: Collect failing/not-ready pods
echo -e "${BLUE}Step 4: Collecting pod status...${NC}"
if kubectl get pods -A > /dev/null 2>&1; then
  kubectl get pods -A -o wide > "$OUTPUT_DIR/pods.txt" 2>&1
  # Get describe for non-running pods
  kubectl get pods -A --no-headers | grep -vE "Running|Completed" | \
    while read ns name rest; do
      echo "=== $ns/$name ===" >> "$OUTPUT_DIR/failing-pods.txt"
      kubectl describe pod "$name" -n "$ns" >> "$OUTPUT_DIR/failing-pods.txt" 2>&1
      echo "" >> "$OUTPUT_DIR/failing-pods.txt"
    done || true
  echo -e "${GREEN}✓ Collected pod status${NC}"
fi
echo ""

# Step 5: Collect warning events
echo -e "${BLUE}Step 5: Extracting warning events...${NC}"
if [ -f "$OUTPUT_DIR/events.txt" ]; then
  grep -i warning "$OUTPUT_DIR/events.txt" > "$OUTPUT_DIR/warnings.txt" 2>&1 || true
  WARNING_COUNT=$(wc -l < "$OUTPUT_DIR/warnings.txt" 2>/dev/null || echo "0")
  echo -e "${GREEN}✓ Found $WARNING_COUNT warning events${NC}"
fi
echo ""

# Step 6: Generate timeline markdown
echo -e "${BLUE}Step 6: Generating timeline markdown...${NC}"
{
  echo "# Post-Mortem Timeline"
  echo ""
  echo "Generated: $(date)"
  echo "Window: Last $HOURS_AGO hours"
  echo ""
  echo "## Recent Events (newest first)"
  echo ""
  echo "| Time | Namespace | Type | Reason | Object | Message |"
  echo "|------|-----------|------|--------|--------|---------|"
  
  # Parse events into table format
  kubectl get events -A --sort-by=.lastTimestamp -o custom-columns=\
TIME:.lastTimestamp,\
NAMESPACE:.metadata.namespace,\
TYPE:.type,\
REASON:.reason,\
OBJECT:.involvedObject.name,\
MESSAGE:.message \
--no-headers 2>/dev/null | tail -50 | while IFS= read -r line; do
    echo "| ${line} |" | sed 's/  */|/g'
  done
  
  echo ""
  echo "## Flux Reconciliation Status"
  echo ""
  echo "\`\`\`"
  kubectl get kustomization -A 2>/dev/null || echo "N/A"
  echo "\`\`\`"
  echo ""
  echo "## Node Status"
  echo ""
  echo "\`\`\`"
  kubectl get nodes 2>/dev/null || echo "N/A"
  echo "\`\`\`"
  echo ""
  echo "## Failing Pods"
  echo ""
  kubectl get pods -A --no-headers 2>/dev/null | grep -vE "Running|Completed" || echo "None"
  
} > "$OUTPUT_DIR/timeline.md"
echo -e "${GREEN}✓ Generated timeline.md${NC}"
echo ""

# Summary
echo -e "${BLUE}=== Collection Complete ===${NC}"
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Files generated:"
ls -la "$OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "  1. Review timeline.md for incident sequence"
echo "  2. Check warnings.txt for error patterns"
echo "  3. Use failing-pods.txt for detailed diagnosis"
echo ""
echo -e "${GREEN}✓ Ready for post-mortem analysis${NC}"
