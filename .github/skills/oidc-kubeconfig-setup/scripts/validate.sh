#!/bin/bash

###########################################
# Part of Kingdon Skills - oidc-kubeconfig-setup
###########################################
# Validates OIDC kubeconfig setup prerequisites and environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== OIDC Kubeconfig Setup Validation ==="
echo ""

# Track overall status
WARNINGS=0
ERRORS=0

########################################
# Step 1: Check Prerequisites
########################################

echo "Step 1: Checking prerequisites..."

# kubectl
if command -v kubectl >/dev/null 2>&1; then
  KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | head -1 || kubectl version --client 2>&1 | head -1)
  echo -e "${GREEN}✓ kubectl installed: $KUBECTL_VERSION${NC}"
else
  echo -e "${RED}✗ kubectl not installed${NC}"
  echo "  Install with: brew install kubectl"
  ((ERRORS++))
fi

# jq
if command -v jq >/dev/null 2>&1; then
  JQ_VERSION=$(jq --version)
  echo -e "${GREEN}✓ jq installed: $JQ_VERSION${NC}"
else
  echo -e "${RED}✗ jq not installed${NC}"
  echo "  Install with: brew install jq"
  ((ERRORS++))
fi

# yq
if command -v yq >/dev/null 2>&1; then
  YQ_VERSION=$(yq --version 2>&1 | head -1)
  echo -e "${GREEN}✓ yq installed: $YQ_VERSION${NC}"
else
  echo -e "${RED}✗ yq not installed${NC}"
  echo "  Install with: brew install yq"
  ((ERRORS++))
fi

# kubelogin (Azure AD - optional)
if command -v kubelogin >/dev/null 2>&1; then
  KUBELOGIN_VERSION=$(kubelogin --version 2>&1 | head -1 || echo "unknown")
  echo -e "${GREEN}✓ kubelogin installed (Azure AD): $KUBELOGIN_VERSION${NC}"
else
  echo -e "${YELLOW}⚠ kubelogin not installed (optional for Azure AD auth)${NC}"
  echo "  Install with: brew install Azure/kubelogin/kubelogin"
  ((WARNINGS++))
fi

# kubectl oidc-login (Dex/generic OIDC - optional)
if kubectl oidc-login --help >/dev/null 2>&1; then
  echo -e "${GREEN}✓ kubectl oidc-login installed (Dex/generic OIDC)${NC}"
else
  echo -e "${YELLOW}⚠ kubectl oidc-login not installed (optional for Dex auth)${NC}"
  echo "  Install with: kubectl krew install oidc-login"
  ((WARNINGS++))
fi

# timeout (optional but recommended)
if command -v timeout >/dev/null 2>&1; then
  echo -e "${GREEN}✓ timeout installed${NC}"
else
  echo -e "${YELLOW}⚠ timeout not installed (optional for connectivity tests)${NC}"
  echo "  Install with: brew install coreutils"
  ((WARNINGS++))
fi

echo ""

########################################
# Step 2: Check OIDC Configuration
########################################

echo "Step 2: Checking OIDC configuration..."

# Check OIDC environment variables
if [[ -n "${OIDC_ISSUER_URL:-}" ]]; then
  echo -e "${GREEN}✓ OIDC_ISSUER_URL is set: $OIDC_ISSUER_URL${NC}"
else
  echo -e "${YELLOW}⚠ OIDC_ISSUER_URL not set${NC}"
  echo "  Example: export OIDC_ISSUER_URL=\"https://dex.example.com\""
  ((WARNINGS++))
fi

if [[ -n "${OIDC_CLIENT_ID:-}" ]]; then
  echo -e "${GREEN}✓ OIDC_CLIENT_ID is set: $OIDC_CLIENT_ID${NC}"
else
  echo -e "${YELLOW}⚠ OIDC_CLIENT_ID not set${NC}"
  echo "  Example: export OIDC_CLIENT_ID=\"kubernetes\""
  ((WARNINGS++))
fi

# Azure AD specific
if [[ -n "${OIDC_TENANT_ID:-}" ]]; then
  echo -e "${BLUE}  OIDC_TENANT_ID is set (Azure AD mode)${NC}"
fi

if [[ -n "${OIDC_SERVER_ID:-}" ]]; then
  echo -e "${BLUE}  OIDC_SERVER_ID is set (Azure AD mode)${NC}"
fi

echo ""

########################################
# Step 3: Check Existing Kubeconfig
########################################

echo "Step 3: Checking kubectl configuration..."

if [[ -n "${KUBECONFIG:-}" ]]; then
  echo -e "${BLUE}  KUBECONFIG is set: $KUBECONFIG${NC}"
elif [[ -f ~/.kube/config ]]; then
  echo "  Using default kubeconfig: ~/.kube/config"
else
  echo "  No kubeconfig found (will be created during setup)"
fi

# Check current context if kubectl is available
if command -v kubectl >/dev/null 2>&1; then
  if CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null); then
    echo -e "${GREEN}✓ Current kubectl context: $CURRENT_CONTEXT${NC}"
    
    # Test connectivity
    if kubectl cluster-info >/dev/null 2>&1; then
      echo -e "${GREEN}  ✓ Cluster is accessible${NC}"
    else
      echo -e "${YELLOW}  ⚠ Cannot connect to cluster${NC}"
      echo "    (May require authentication)"
      ((WARNINGS++))
    fi
  else
    echo "  No current kubectl context set"
  fi
fi

echo ""

########################################
# Step 4: Check Output Directory
########################################

echo "Step 4: Checking output directory..."

OUTPUT_DIR="./kubeconfigs"
if [[ -d "$OUTPUT_DIR" ]]; then
  KUBECONFIG_COUNT=$(find "$OUTPUT_DIR" -name "kubeconfig-*" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo -e "${GREEN}✓ Output directory exists: $OUTPUT_DIR/${NC}"
  echo "  Contains $KUBECONFIG_COUNT kubeconfig file(s)"
  
  if [[ "$KUBECONFIG_COUNT" -gt 0 ]]; then
    echo "  Recent kubeconfigs:"
    find "$OUTPUT_DIR" -name "kubeconfig-*" -type f -exec basename {} \; | head -5 | sed 's/^/    - /'
  fi
else
  echo "  Output directory will be created: $OUTPUT_DIR/"
fi

echo ""

########################################
# Summary
########################################

echo "=== Validation Summary ==="
echo ""

if [[ "$ERRORS" -eq 0 ]] && [[ "$WARNINGS" -eq 0 ]]; then
  echo -e "${GREEN}✓ All checks passed! Ready to run setup-kubeconfig.sh${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Set OIDC environment variables:"
  echo "     export OIDC_ISSUER_URL=\"https://dex.example.com\""
  echo "     export OIDC_CLIENT_ID=\"kubernetes\""
  echo ""
  echo "  2. Run the setup script:"
  echo "     bash .github/skills/oidc-kubeconfig-setup/scripts/setup-kubeconfig.sh"
  exit 0
elif [[ "$ERRORS" -eq 0 ]]; then
  echo -e "${YELLOW}⚠ Validation completed with $WARNINGS warning(s)${NC}"
  echo ""
  echo "You can proceed, but some features may require additional setup."
  exit 0
else
  echo -e "${RED}✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
  echo ""
  echo "Please install missing prerequisites before running setup."
  exit 1
fi
