#!/usr/bin/env bash

###########################################
# Part of Kingdon Skills - oidc-kubeconfig-setup
###########################################
# Interactive kubeconfig generation with OIDC authentication
# Supports Dex, Azure AD, Keycloak, and other OIDC providers

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# OIDC Configuration from environment variables
# Generic OIDC (Dex, Keycloak, etc.)
OIDC_ISSUER_URL="${OIDC_ISSUER_URL:-}"
OIDC_CLIENT_ID="${OIDC_CLIENT_ID:-kubernetes}"
OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET:-}"

# Azure AD specific (optional)
OIDC_TENANT_ID="${OIDC_TENANT_ID:-}"
OIDC_SERVER_ID="${OIDC_SERVER_ID:-$OIDC_CLIENT_ID}"

# Output directory
OUTPUT_DIR="./kubeconfigs"
TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

########################################
# Utility Functions
########################################

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo -e "${RED}✗ Missing required command: $1${NC}" >&2
    exit 1
  fi
}

# Detect OIDC mode based on environment variables
detect_oidc_mode() {
  if [[ -n "$OIDC_TENANT_ID" ]]; then
    echo "azure"
  elif [[ -n "$OIDC_ISSUER_URL" ]]; then
    echo "generic"
  else
    echo "none"
  fi
}

# Generate kubelogin user config for Azure AD
generate_azure_user() {
  local user_name=$1
  cat <<EOF
- name: $user_name
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - get-token
      - --server-id
      - $OIDC_SERVER_ID
      - --client-id
      - $OIDC_CLIENT_ID
      - --tenant-id
      - $OIDC_TENANT_ID
      command: kubelogin
      env: null
      interactiveMode: IfAvailable
      provideClusterInfo: false
EOF
}

# Generate oidc-login user config for Dex/generic OIDC
generate_oidc_user() {
  local user_name=$1
  cat <<EOF
- name: $user_name
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: kubectl
      args:
      - oidc-login
      - get-token
      - --oidc-issuer-url=$OIDC_ISSUER_URL
      - --oidc-client-id=$OIDC_CLIENT_ID
EOF
  
  # Add client secret if provided
  if [[ -n "$OIDC_CLIENT_SECRET" ]]; then
    cat <<EOF
      - --oidc-client-secret=$OIDC_CLIENT_SECRET
EOF
  fi
  
  cat <<EOF
      interactiveMode: IfAvailable
      provideClusterInfo: false
EOF
}

########################################
# Main Script
########################################

echo "=== OIDC Kubeconfig Setup ==="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
require kubectl
require jq
require yq

# Detect OIDC mode
OIDC_MODE=$(detect_oidc_mode)

case "$OIDC_MODE" in
  azure)
    echo -e "${BLUE}Mode: Azure AD (kubelogin)${NC}"
    if ! command -v kubelogin >/dev/null 2>&1; then
      echo -e "${RED}✗ kubelogin required for Azure AD mode${NC}"
      echo "  Install with: brew install Azure/kubelogin/kubelogin"
      exit 1
    fi
    OIDC_USER_NAME="oidc-azure"
    ;;
  generic)
    echo -e "${BLUE}Mode: Generic OIDC (oidc-login)${NC}"
    if ! kubectl oidc-login --help >/dev/null 2>&1; then
      echo -e "${YELLOW}⚠ kubectl oidc-login not found${NC}"
      echo "  Install with: kubectl krew install oidc-login"
      echo "  Continuing, but authentication may not work without it"
    fi
    OIDC_USER_NAME="oidc-user"
    ;;
  none)
    echo -e "${YELLOW}⚠ No OIDC configuration detected${NC}"
    echo ""
    echo "Please set environment variables:"
    echo ""
    echo "For Dex/Keycloak/generic OIDC:"
    echo "  export OIDC_ISSUER_URL=\"https://dex.example.com\""
    echo "  export OIDC_CLIENT_ID=\"kubernetes\""
    echo ""
    echo "For Azure AD:"
    echo "  export OIDC_CLIENT_ID=\"your-client-id\""
    echo "  export OIDC_TENANT_ID=\"your-tenant-id\""
    echo ""
    exit 1
    ;;
esac

echo ""

# Check for timeout command (optional)
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_AVAILABLE=true
else
  echo -e "${YELLOW}⚠ timeout command not found (optional)${NC}"
  TIMEOUT_AVAILABLE=false
fi

# Get cluster information interactively
echo "Enter cluster details:"
echo ""

read -rp "Cluster API server URL (e.g., https://kubernetes.example.com:6443): " CLUSTER_SERVER
if [[ -z "$CLUSTER_SERVER" ]]; then
  echo -e "${RED}✗ Cluster server URL is required${NC}"
  exit 1
fi

read -rp "Cluster name (e.g., my-cluster): " CLUSTER_NAME
if [[ -z "$CLUSTER_NAME" ]]; then
  CLUSTER_NAME="cluster"
fi

read -rp "CA certificate file path (optional, press Enter to skip): " CA_CERT_PATH

echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate kubeconfig
KUBECONFIG_FILE="$OUTPUT_DIR/kubeconfig-${CLUSTER_NAME}"

# Check if file exists
if [[ -f "$KUBECONFIG_FILE" ]]; then
  echo -e "${YELLOW}⚠ File exists: $KUBECONFIG_FILE${NC}"
  read -rp "  Overwrite? (y/N): " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    echo "  Exiting..."
    exit 0
  fi
fi

echo -e "${BLUE}Generating kubeconfig for: $CLUSTER_NAME${NC}"

# Build cluster configuration
CLUSTER_CONFIG=$(cat <<EOF
apiVersion: v1
kind: Config
preferences: {}
current-context: $CLUSTER_NAME
clusters:
- name: $CLUSTER_NAME
  cluster:
    server: $CLUSTER_SERVER
EOF
)

# Add CA certificate if provided
if [[ -n "$CA_CERT_PATH" ]] && [[ -f "$CA_CERT_PATH" ]]; then
  CA_DATA=$(base64 < "$CA_CERT_PATH" | tr -d '\n')
  CLUSTER_CONFIG=$(cat <<EOF
$CLUSTER_CONFIG
    certificate-authority-data: $CA_DATA
EOF
)
else
  # Skip TLS verification if no CA provided (not recommended for production)
  CLUSTER_CONFIG=$(cat <<EOF
$CLUSTER_CONFIG
    insecure-skip-tls-verify: true
EOF
)
  echo -e "${YELLOW}⚠ No CA certificate - TLS verification disabled${NC}"
fi

# Add context
CLUSTER_CONFIG=$(cat <<EOF
$CLUSTER_CONFIG
contexts:
- name: $CLUSTER_NAME
  context:
    cluster: $CLUSTER_NAME
    user: $OIDC_USER_NAME
EOF
)

# Write base config
echo "$CLUSTER_CONFIG" > "$KUBECONFIG_FILE"

# Append OIDC user configuration
echo "users:" >> "$KUBECONFIG_FILE"

case "$OIDC_MODE" in
  azure)
    generate_azure_user "$OIDC_USER_NAME" >> "$KUBECONFIG_FILE"
    ;;
  generic)
    generate_oidc_user "$OIDC_USER_NAME" >> "$KUBECONFIG_FILE"
    ;;
esac

echo -e "${GREEN}✓ Kubeconfig created: $KUBECONFIG_FILE${NC}"
echo ""

# Test connectivity
echo "Testing connectivity..."
if [[ "$TIMEOUT_AVAILABLE" == true ]]; then
  if timeout 10 kubectl --kubeconfig="$KUBECONFIG_FILE" cluster-info 2>&1 | head -5; then
    echo -e "${GREEN}✓ Cluster accessible${NC}"
  else
    echo -e "${YELLOW}⚠ Could not verify connectivity${NC}"
    echo "  (First use may require browser authentication)"
  fi
else
  echo -e "${YELLOW}⚠ Running connectivity test without timeout - press Ctrl-C if it hangs${NC}"
  if kubectl --kubeconfig="$KUBECONFIG_FILE" cluster-info 2>&1 | head -5; then
    echo -e "${GREEN}✓ Cluster accessible${NC}"
  else
    echo -e "${YELLOW}⚠ Could not verify connectivity${NC}"
    echo "  (First use may require browser authentication)"
  fi
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To use this kubeconfig:"
echo "  export KUBECONFIG=\$(pwd)/$KUBECONFIG_FILE"
echo ""
echo "Or test directly:"
echo "  kubectl --kubeconfig=$KUBECONFIG_FILE get nodes"
echo ""
echo "On first use, a browser window will open for OIDC authentication."
