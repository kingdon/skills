---
name: resource-template-engine
description: 'Operate the templating system for onboarding new Crossplane resource types with automated metric configuration and alert rule generation. Trigger with /template-generate'
allowed-tools: ['read_file', 'create_file', 'replace_string_in_file', 'run_in_terminal', 'semantic_search']
---

# Resource Template Engine Operator

I operate the automated templating system that onboards new Crossplane resource types by generating kube-state-metrics configurations and alert rules based on superficial resource knowledge and pattern matching.

## Slash Command

### `/template-generate`
Runs the full resource discovery and template generation workflow:
1. Verify Kubernetes cluster connectivity
2. Check Crossplane installation
3. Discover and categorize Crossplane resource types (database, network, compute, storage)
4. Check existing KSM configurations
5. Check existing PrometheusRules for Crossplane
6. Identify resources needing metric templates
7. Validate template directory structure
8. Generate recommendations for new templates

**Usage**: Type `/template-generate` to discover Crossplane resources and identify which need metric configurations.

**Script Verification**: Before executing, verify the script integrity:
```bash
sha256sum .github/skills/resource-template-engine/scripts/validate.sh
# Expected: check current hash after creation
```

**Execute validation**:
```bash
bash .github/skills/resource-template-engine/scripts/validate.sh
```

## When I Activate
- `/template-generate` (slash command)
- "Onboard new resource type"
- "Generate metrics for provider"
- "Add monitoring for Crossplane resource"
- "Template new alerts"
- "Automate resource monitoring"

## Port-Forward Assumptions
This skill assumes port-forwards are active or can be started:
- **Prometheus**: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &`

## Template System Architecture

### Input Requirements (Superficial Knowledge)
For any new resource, I only need:
1. **Resource identification**: Group/Version/Kind (GVK)
2. **Resource category**: Database, Network, Compute, Storage, etc.
3. **Provider type**: AWS, GCP, Azure, or generic
4. **Deployment confirmation**: `kubectl get <resource>` works

### Automated Discovery Process
```bash
# Step 1: Discover installed providers
kubectl get providers.pkg.crossplane.io -o jsonpath='{.items[*].metadata.name}'

# Step 2: Extract available resource types
kubectl api-resources --api-group="*.crossplane.io" --no-headers

# Step 3: Categorize by naming patterns
# Database: *sql*, *db*, *database*, *redis*, *mongo*
# Network: *vpc*, *subnet*, *security*, *route*, *lb*
# Compute: *instance*, *cluster*, *node*, *vm*
# Storage: *bucket*, *disk*, *volume*, *blob*
```

## Template Categories

### Database Resource Template
```yaml
# Applies to: RDS, CloudSQL, PostgreSQL, MySQL, etc.
apiVersion: v1
kind: ConfigMap
metadata:
  name: ksm-crossplane-{{ .ResourceType | lower }}
  namespace: monitoring
data:
  {{ .ResourceType | lower }}.yaml: |
    customResourceState:
      enabled: true
      config:
        spec:
          resources:
            - groupVersionKind:
                group: {{ .Group }}
                version: {{ .Version }}  
                kind: {{ .Kind }}
              labelFromKey: metadata.name
              metricNamePrefix: crossplane_{{ .Provider | lower }}_{{ .Category | lower }}
              metrics:
                - name: ready_status
                  help: "{{ .Kind }} ready condition status"
                  each:
                    type: Gauge
                    gauge:
                      path: |
                        status.conditions[?(@.type=="Ready")].status
                      valueFrom:
                        "True": 1
                        "False": 0
                - name: synced_status
                  help: "{{ .Kind }} synced condition status"
                  each:
                    type: Gauge
                    gauge:
                      path: |
                        status.conditions[?(@.type=="Synced")].status
                      valueFrom:
                        "True": 1
                        "False": 0
                - name: creation_time
                  help: "{{ .Kind }} creation timestamp"
                  each:
                    type: Gauge
                    gauge:
                      path: metadata.creationTimestamp
                      nilIsZero: true
---
# Corresponding alert rules
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: crossplane-{{ .ResourceType | lower }}-alerts
  namespace: monitoring
spec:
  groups:
    - name: crossplane.{{ .ResourceType | lower }}
      rules:
        - alert: {{ .Kind }}NotReady
          expr: |
            crossplane_{{ .Provider | lower }}_{{ .Category | lower }}_ready_status == 0
            and
            crossplane_{{ .Provider | lower }}_{{ .Category | lower }}_synced_status == 1
          for: 10m
          labels:
            severity: warning
            category: {{ .Category | lower }}
            provider: {{ .Provider | lower }}
          annotations:
            summary: "{{ .Kind }} {{`{{ $labels.name }}`}} not ready"
            description: "Crossplane {{ .Kind }} resource is synced but not ready for more than 10 minutes"
        
        - alert: {{ .Kind }}NotSynced  
          expr: crossplane_{{ .Provider | lower }}_{{ .Category | lower }}_synced_status == 0
          for: 5m
          labels:
            severity: critical
            category: {{ .Category | lower }}
            provider: {{ .Provider | lower }}
          annotations:
            summary: "{{ .Kind }} {{`{{ $labels.name }}`}} not synced"
            description: "Crossplane {{ .Kind }} resource configuration has drifted from desired state"
```

### Network Resource Template
```yaml
# Applies to: VPC, Subnet, SecurityGroup, LoadBalancer, etc.
# Similar structure with network-specific metrics:
metrics:
  - name: ready_status
    # Standard ready/synced conditions
  - name: external_name
    help: "External cloud resource identifier"
    each:
      type: Info
      gauge:
        path: metadata.annotations["crossplane.io/external-name"]
  - name: cidr_block
    help: "Network CIDR block"
    each:
      type: Info
      gauge:
        path: spec.forProvider.cidrBlock
```

### Compute Resource Template
```yaml
# Applies to: EC2Instance, GKECluster, AKSCluster, etc.
# Includes compute-specific metrics:
metrics:
  - name: ready_status
    # Standard conditions
  - name: instance_state
    help: "Compute instance state"
    each:
      type: Info
      gauge:
        path: status.atProvider.instanceState
  - name: cpu_count
    help: "Number of CPU cores"
    each:
      type: Gauge
      gauge:
        path: spec.forProvider.instanceType
        # Translate instance types to CPU counts via lookup table
```

### Storage Resource Template  
```yaml
# Applies to: S3Bucket, GCSBucket, Disk, etc.
metrics:
  - name: ready_status
    # Standard conditions
  - name: size_gb
    help: "Storage size in GB"
    each:
      type: Gauge
      gauge:
        path: spec.forProvider.size
  - name: storage_class
    help: "Storage tier/class"
    each:
      type: Info
      gauge:
        path: spec.forProvider.storageClass
```

## Pattern Matching Logic

### Resource Categorization
```go
// Pattern matching for automatic categorization
func categorizeResource(kind string, group string) string {
    kind = strings.ToLower(kind)
    group = strings.ToLower(group)
    
    // Database patterns
    if containsAny(kind, []string{"db", "sql", "database", "redis", "mongo", "postgres", "mysql"}) {
        return "database"
    }
    
    // Network patterns  
    if containsAny(kind, []string{"vpc", "subnet", "security", "route", "gateway", "lb", "loadbalancer"}) {
        return "network"
    }
    
    // Compute patterns
    if containsAny(kind, []string{"instance", "cluster", "node", "vm", "compute"}) {
        return "compute" 
    }
    
    // Storage patterns
    if containsAny(kind, []string{"bucket", "disk", "volume", "blob", "storage"}) {
        return "storage"
    }
    
    return "generic"
}
```

### Provider Detection
```go
func detectProvider(group string) string {
    switch {
    case strings.Contains(group, "aws"):
        return "aws"
    case strings.Contains(group, "gcp"):
        return "gcp"  
    case strings.Contains(group, "azure"):
        return "azure"
    case strings.Contains(group, "kubernetes"):
        return "kubernetes"
    default:
        return "generic"
    }
}
```

## Onboarding Automation

### Resource Discovery Workflow
```bash
#!/bin/bash
# discover-new-resources.sh

# Find all Crossplane CRDs not yet monitored
echo "Discovering new Crossplane resources..."

EXISTING_CONFIGS=$(kubectl get configmaps -n monitoring -l app=ksm-crossplane -o name | cut -d'/' -f2)
ALL_CROSSPLANE_CRDS=$(kubectl get crds -o name | grep "\.crossplane\.io" | cut -d'/' -f2)

for crd in $ALL_CROSSPLANE_CRDS; do
    RESOURCE_NAME=$(echo $crd | cut -d'.' -f1)
    
    if ! echo "$EXISTING_CONFIGS" | grep -q "ksm-crossplane-$RESOURCE_NAME"; then
        echo "New resource found: $crd"
        
        # Extract resource details
        GROUP=$(kubectl get crd $crd -o jsonpath='{.spec.group}')
        VERSION=$(kubectl get crd $crd -o jsonpath='{.spec.versions[0].name}')
        KIND=$(kubectl get crd $crd -o jsonpath='{.spec.names.kind}')
        
        # Apply template
        ./generate-template.sh "$GROUP" "$VERSION" "$KIND"
    fi
done
```

### Template Generation Script
```bash
#!/bin/bash
# generate-template.sh GROUP VERSION KIND

GROUP=$1
VERSION=$2  
KIND=$3

# Detect provider and category
PROVIDER=$(echo $GROUP | cut -d'.' -f1)
CATEGORY=$(detect_category $KIND)

# Generate from template
envsubst < templates/${CATEGORY}-template.yaml > generated/ksm-${KIND,,}.yaml

# Apply configuration
kubectl apply -f generated/ksm-${KIND,,}.yaml

echo "Generated monitoring config for $KIND ($PROVIDER $CATEGORY)"
```

## Validation and Testing

### Configuration Validation
```bash
# Check generated configs are valid
kubectl apply --dry-run=client -f generated/

# Verify KSM picks up new configs
kubectl logs -n monitoring deployment/kube-state-metrics | grep "new custom resource"

# Test metric collection
sleep 30
curl -s http://prometheus:9090/api/v1/label/__name__/values | grep crossplane_${PROVIDER}_${CATEGORY}
```

### Alert Rule Testing
```bash
# Validate PrometheusRule syntax
promtool check rules generated/alerts-${KIND,,}.yaml

# Test alert queries  
curl -s "http://prometheus:9090/api/v1/query?query=crossplane_${PROVIDER}_${CATEGORY}_ready_status"

# Verify alerts are loaded
kubectl get prometheusrule -n monitoring | grep crossplane-${KIND,,}
```

## Error Handling and Rollback

### Common Template Issues
1. **Invalid Resource Paths**: Resource doesn't have expected structure
2. **High cardinality**: Resource creates too many metric series
3. **Missing permissions**: KSM can't access resource type

### Rollback Process
```bash
# Remove problematic configuration
kubectl delete configmap ksm-crossplane-${RESOURCE} -n monitoring

# Remove alert rules
kubectl delete prometheusrule crossplane-${RESOURCE}-alerts -n monitoring

# Restart KSM to reload configs
kubectl rollout restart deployment/kube-state-metrics -n monitoring
```

### Template Refinement
```yaml
# Fallback template for unknown patterns
apiVersion: v1
kind: ConfigMap
metadata:
  name: ksm-crossplane-{{ .Kind | lower }}
  namespace: monitoring
data:
  config.yaml: |
    # Minimal monitoring with just Ready condition
    customResourceState:
      enabled: true
      config:
        spec:
          resources:
            - groupVersionKind:
                group: {{ .Group }}
                version: {{ .Version }}
                kind: {{ .Kind }}
              metrics:
                - name: info
                  help: "{{ .Kind }} resource info"
                  each:
                    type: Info
                    info:
                      path: metadata
                      labelsFromPath:
                        name: name
                        namespace: namespace
```

## Integration Points

This skill orchestrates the complete monitoring onboarding process:
- **KSM Crossplane Adapter** - Provides pattern knowledge and templates
- **Prometheus Observer** - Validates metrics are collected successfully  
- **AlertManager Installer** - Ensures alerts have proper notification routing
- **Author Skills** - Used when new resource categories require template expansion

The engine operates autonomously but reports when manual intervention is needed for truly novel resource patterns.