---
name: oidc-kubeconfig-setup
description: 'Configure kubectl access to Kubernetes clusters with OIDC authentication (Dex, Azure AD, Keycloak). Validates environment, generates kubeconfigs, and tests connectivity. Trigger with /kubeconfig-setup'
allowed-tools: ['read_file', 'run_in_terminal', 'grep_search', 'semantic_search', 'get_terminal_output']
---

# OIDC Kubeconfig Setup

I help you configure kubectl access to Kubernetes clusters using OIDC authentication. I validate your environment, generate kubeconfig files with proper OIDC token configuration, and test connectivity. I'm the prerequisite for all cluster-dependent skills.

**Supported OIDC Providers**:
- Dex (with GitHub, GitLab, LDAP connectors)
- Azure Entra ID (Azure AD)
- Keycloak
- Any OIDC-compliant identity provider

## Slash Commands

### `/kubeconfig-setup`
Runs environment validation and provides setup guidance:
1. Verify kubectl, jq, and authentication tools installed
2. Check for existing kubeconfig and contexts
3. Validate OIDC configuration
4. Test cluster connectivity

**Usage**: Type `/kubeconfig-setup` and I will validate your environment.

**Execute validation**:
```bash
bash .github/skills/oidc-kubeconfig-setup/scripts/validate.sh
```

### `/kubeconfig-configure`
Runs cluster discovery and kubeconfig generation:
1. Check prerequisites and credentials
2. Discover available clusters
3. Generate kubeconfig files with OIDC authentication
4. Test cluster connectivity

**Execute setup**:
```bash
bash .github/skills/oidc-kubeconfig-setup/scripts/setup-kubeconfig.sh
```

## When I Activate
- `/kubeconfig-setup` (validation)
- `/kubeconfig-configure` (setup)
- "Configure kubeconfig"
- "Setup OIDC access"
- "Connect to Kubernetes cluster"
- "I need a kubeconfig"
- "Can't connect to Kubernetes"
- "Setup kubectl with Dex"

## Core Capabilities

### 1. Environment Validation
Checks all prerequisites before attempting configuration:

```bash
# Prerequisites
- kubectl (1.28+)
- jq (JSON processor)
- yq (YAML processor)
- kubelogin (for Azure AD) OR oidc-login (for Dex/generic OIDC)
```

**Installation**:
```bash
# macOS
brew install kubectl jq yq

# For Azure Entra ID
brew install Azure/kubelogin/kubelogin

# For Dex/generic OIDC (kubelogin kubectl plugin)
kubectl krew install oidc-login
```

### 2. OIDC Authentication Patterns

OIDC decouples identity from Kubernetes, enabling centralized authentication through your identity provider.

#### Pattern A: Dex with GitHub (Recommended for Open Source)

Dex is an identity service that uses OpenID Connect to drive authentication. It acts as a portal to other identity providers (GitHub, GitLab, LDAP, etc.).

**Reference Documentation**:
- [Weave GitOps: Setting up Dex](https://docs.gitops.weaveworks.org/docs/0.25.0/guides/setting-up-dex/)
- [Weave GitOps: Recommended RBAC Configuration](https://docs.gitops.weaveworks.org/docs/0.29.0/configuration/recommended-rbac-configuration/)

**GitHub Organization Groups**:
```yaml
# Dex connector configuration
connectors:
  - type: github
    id: github
    name: GitHub
    config:
      clientID: $GITHUB_CLIENT_ID
      clientSecret: $GITHUB_CLIENT_SECRET
      redirectURI: https://dex.example.com/callback
      orgs:
        - name: your-org
          teams:
            - platform-team
            - developers
```

**Control Plane OIDC Configuration**:
For configuring your Kubernetes API server to accept Dex tokens, see:
- [Example Kubeconfig with OIDC](https://github.com/kingdon-ci/example-kubeconfig/blob/main/src/index.md)

This pattern works with kubeadm, vcluster, k3s, and other distributions.

#### Pattern B: Azure Entra ID (Enterprise)

For organizations using Microsoft identity:

```yaml
# Kubeconfig user configuration
users:
  - name: oidc-user
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        command: kubelogin
        args:
          - get-token
          - --server-id
          - $OIDC_SERVER_ID
          - --client-id
          - $OIDC_CLIENT_ID
          - --tenant-id
          - $OIDC_TENANT_ID
        interactiveMode: IfAvailable
```

#### Pattern C: EKS with OIDC Identity Providers

Amazon EKS has first-class support for OIDC identity providers and access policy associations.

**Reference**:
- [EKS Blueprints for CDK with Auto Mode](https://aws.amazon.com/blogs/containers/amazon-eks-blueprints-for-cdk-now-supporting-amazon-eks-auto-mode/)

EKS AccessEntry and AccessPolicyAssociation resources allow you to map OIDC identities to Kubernetes RBAC:

```yaml
# Crossplane-style AccessEntry (conceptual)
apiVersion: eks.aws.upbound.io/v1beta1
kind: AccessEntry
spec:
  forProvider:
    clusterName: my-cluster
    principalArn: arn:aws:iam::ACCOUNT:role/my-oidc-role
    type: STANDARD
```

### 3. Kubeconfig Generation

The setup script generates kubeconfigs with OIDC authentication configured.

**Configuration via Environment Variables**:
```bash
# Required for OIDC
export OIDC_ISSUER_URL="https://dex.example.com"
export OIDC_CLIENT_ID="my-client-id"
export OIDC_CLIENT_SECRET="my-client-secret"  # Optional for some flows

# Optional
export OIDC_TENANT_ID="..."  # For Azure AD
export OIDC_SERVER_ID="..."  # For Azure AD (often same as client ID)
```

**Naming Convention**:
```
./kubeconfigs/kubeconfig-{context-name}
```

### 4. RBAC Configuration

OIDC groups map to Kubernetes RBAC. The Weave GitOps pattern recommends:

1. **Create groups in your IdP** (GitHub teams, Azure AD groups, etc.)
2. **Configure Dex/OIDC to pass groups as claims**
3. **Bind Kubernetes roles to groups**

```yaml
# ClusterRoleBinding for admin group
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-admins
subjects:
  - kind: Group
    name: platform-team  # Matches OIDC group claim
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

### 5. Context Management

Kubeconfigs use descriptive context names:

```bash
# Switch between contexts
kubectl config use-context my-cluster

# View available contexts
kubectl config get-contexts

# Use specific kubeconfig
export KUBECONFIG=$(pwd)/kubeconfigs/kubeconfig-my-cluster
kubectl cluster-info
```

## Workflow Examples

### Dex + GitHub Setup
```bash
# 1. Deploy Dex to your cluster (see Weave GitOps docs)
# 2. Create GitHub OAuth application
# 3. Configure Dex with GitHub connector
# 4. Configure API server with OIDC flags

# 5. Generate kubeconfig with OIDC
export OIDC_ISSUER_URL="https://dex.example.com"
export OIDC_CLIENT_ID="kubernetes"
bash .github/skills/oidc-kubeconfig-setup/scripts/setup-kubeconfig.sh

# 6. Test authentication
kubectl get nodes
# Browser opens for GitHub authentication
```

### Azure AD Setup
```bash
# 1. Configure Azure AD application registration
# 2. Set environment variables
export OIDC_CLIENT_ID="your-client-id"
export OIDC_TENANT_ID="your-tenant-id"

# 3. Run setup
bash .github/skills/oidc-kubeconfig-setup/scripts/setup-kubeconfig.sh

# 4. Authenticate
kubectl get nodes
# Browser opens for Microsoft authentication
```

## Troubleshooting

### Token Expired
```
error: You must be logged in to the server (Unauthorized)
```

**Solution**: Re-authenticate through your OIDC provider. Delete cached tokens if needed:
```bash
rm -rf ~/.kube/cache/oidc-login/
```

### Wrong Groups/Permissions
```
Error from server (Forbidden): pods is forbidden
```

**Check**:
1. Verify group claims are being passed correctly
2. Check ClusterRoleBindings match your group names
3. Use `kubectl auth whoami` (K8s 1.28+) to see your identity

### Dex Connection Failed
```
error: unable to get token: oidc: issuer did not match
```

**Cause**: Issuer URL mismatch between kubeconfig and Dex configuration.

**Solution**: Ensure `OIDC_ISSUER_URL` exactly matches Dex's issuer configuration.

## Reference Documentation

### Dex Setup
- [Weave GitOps: Setting up Dex](https://docs.gitops.weaveworks.org/docs/0.25.0/guides/setting-up-dex/)
- [Weave GitOps: Recommended RBAC Configuration](https://docs.gitops.weaveworks.org/docs/0.29.0/configuration/recommended-rbac-configuration/)
- [Example Kubeconfig with OIDC Control Plane Setup](https://github.com/kingdon-ci/example-kubeconfig/blob/main/src/index.md)

### AWS EKS
- [EKS Blueprints for CDK with Auto Mode](https://aws.amazon.com/blogs/containers/amazon-eks-blueprints-for-cdk-now-supporting-amazon-eks-auto-mode/)
- EKS supports OIDC identity providers natively via AccessEntry and AccessPolicyAssociation

### Alternative Identity Providers
- [Keycloak](https://www.keycloak.org/) - Full-featured identity management
- [Authentik](https://goauthentik.io/) - Open source identity provider
- [Zitadel](https://zitadel.com/) - Cloud-native identity management

## Integration Points

### Prerequisite For
- **flux-operator** - Requires kubeconfig for GitOps validation
- **prometheus-observer** - Needs cluster access for metrics
- **alertmanager-installer** - Requires connectivity to install alerts
- **ksm-crossplane-adapter** - Needs access to observe Crossplane resources

### Works Alongside
- **Dex** - Identity service for OIDC
- **kubelogin** - Azure AD authentication plugin
- **oidc-login** - Generic OIDC kubectl plugin

## Quick Reference

### Prerequisites Check
```bash
# Verify tools installed
kubectl version --client
jq --version
yq --version

# Check for OIDC plugins
kubelogin --version  # Azure AD
kubectl oidc-login --version  # Generic OIDC
```

### Environment Variables
```bash
# Generic OIDC (Dex, Keycloak, etc.)
export OIDC_ISSUER_URL="https://dex.example.com"
export OIDC_CLIENT_ID="kubernetes"
export OIDC_CLIENT_SECRET=""  # Often empty for public clients

# Azure AD specific
export OIDC_TENANT_ID="your-tenant-id"
export OIDC_SERVER_ID="your-server-id"  # Often same as client ID
```

### Generate Kubeconfig
```bash
bash .github/skills/oidc-kubeconfig-setup/scripts/setup-kubeconfig.sh
```

### Test Connectivity
```bash
export KUBECONFIG=$(pwd)/kubeconfigs/kubeconfig-my-cluster
kubectl cluster-info
kubectl get nodes
```

## Success Criteria

You know this skill worked when:
- ✓ All prerequisites installed and verified
- ✓ OIDC configuration validated
- ✓ Kubeconfig files created in ./kubeconfigs/
- ✓ OIDC authentication configured (kubelogin or oidc-login)
- ✓ kubectl can connect to clusters after browser authentication
- ✓ RBAC groups properly mapped
- ✓ Ready to run flux-operator and other cluster-dependent skills
