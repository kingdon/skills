---
name: ksm-crossplane-adapter
description: 'Adapt kube-state-metrics configuration for monitoring non-Flux resources like Crossplane Managed Resources and Compositions beyond standard KStatus patterns'
allowed-tools: ['read_file', 'grep_search', 'run_in_terminal', 'semantic_search', 'get_terminal_output']
---

# KSM Crossplane Adapter

I adapt kube-state-metrics configurations to enable monitoring of Crossplane Managed Resources and Compositions, extending beyond standard Flux patterns to handle Crossplane's unique Synced and Ready condition patterns.

## When I Activate
- "Adapt metrics for Crossplane"
- "Configure kube-state-metrics for Crossplane"
- "Monitor Crossplane resources"
- "Set up Crossplane alerts"
- "Extend KSM for custom resources"

## Crossplane vs Standard Kubernetes Patterns

### Standard KStatus Pattern (Flux)
Most Kubernetes resources follow the KStatus convention:
```yaml
status:
  conditions:
    - type: Ready
      status: "True"
      reason: ReconciliationSucceeded
```

### Crossplane Extended Pattern
Crossplane adds additional condition types:
```yaml
status:
  conditions:
    - type: Synced    # Resource matches desired state
      status: "True"
    - type: Ready     # Resource is functional/healthy
      status: "True"  
```

## Resource Categories We Monitor

### 1. Crossplane Core Resources
- **Providers**: Install and manage cloud provider APIs
- **ProviderConfigs**: Authentication and configuration
- **CompositeResourceDefinitions (XRDs)**: Schema definitions
- **Compositions**: Resource templates

### 2. Managed Resources (Cloud Resources)
- **Database instances**: RDS, CloudSQL, PostgreSQL
- **Storage**: S3 buckets, persistent volumes
- **Networking**: VPCs, subnets, security groups
- **Compute**: EC2 instances, GKE clusters

### 3. Composite Resources (Claims)
- **Application stacks**: Complete environment definitions
- **Platform resources**: Shared infrastructure components

## KSM Configuration Patterns

### Base Configuration Structure
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-state-metrics-config
  namespace: monitoring
data:
  config.yaml: |
    apiVersion: kube-state-metrics/v1alpha1
    kind: MetricConfig
    spec:
      metricLabelsAllowlist:
        - customresources=[crossplane.io/composite,crossplane.io/claim-name]
      metricAnnotationsAllowlist:
        - customresources=[crossplane.io/*]
```

### Crossplane-Specific Metrics
```yaml
# Custom resource metrics for Crossplane
customResourceState:
  enabled: true
  groupVersionKinds:
    - group: pkg.crossplane.io
      version: v1
      kind: Provider
      labelFromKey: metadata.name
      metricNamePrefix: crossplane_provider
      metrics:
        - name: condition_status
          help: Crossplane Provider condition status
          each:
            type: Gauge
            gauge:
              labelFromKey: type
              valuePath: status.conditions[*].status
              labelsFromPath:
                condition: status.conditions[*].type
                reason: status.conditions[*].reason
```

### Managed Resource Monitoring Template
```yaml
# Template for monitoring managed resources
- group: rds.aws.crossplane.io
  version: v1alpha1
  kind: DBInstance
  labelFromKey: metadata.name
  metricNamePrefix: crossplane_aws_rds
  metrics:
    - name: ready_status
      help: RDS instance ready status
      each:
        type: Gauge
        gauge:
          path: status.conditions[?(@.type=="Ready")].status
          valueFrom: 
            - "True": 1
            - "False": 0
    - name: synced_status
      help: RDS instance sync status  
      each:
        type: Gauge
        gauge:
          path: status.conditions[?(@.type=="Synced")].status
          valueFrom:
            - "True": 1
            - "False": 0
```

## Alert Rule Patterns

### Generic Crossplane Alerts
```yaml
groups:
  - name: crossplane.rules
    rules:
      - alert: CrossplaneResourceNotReady
        expr: |
          (
            crossplane_resource_condition_status{condition="Ready"} == 0
          ) and on(name, namespace) (
            crossplane_resource_condition_status{condition="Synced"} == 1  
          )
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Crossplane resource {{ $labels.name }} not ready"
          description: "Resource is synced but not ready for {{ $labels.for }}"

      - alert: CrossplaneResourceNotSynced
        expr: crossplane_resource_condition_status{condition="Synced"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Crossplane resource {{ $labels.name }} not synced"
          description: "Resource configuration drift detected"
```

### Provider-Specific Alerts
```yaml
# AWS RDS specific alerts
- alert: RDSInstanceNotReady
  expr: crossplane_aws_rds_ready_status == 0
  for: 10m
  labels:
    severity: critical
    category: database
  annotations:
    summary: "RDS instance {{ $labels.name }} not ready"
    runbook_url: "https://docs.crossplane.io/troubleshoot/managed-resources/"

# GCP CloudSQL alerts  
- alert: CloudSQLInstanceNotReady
  expr: crossplane_gcp_sql_ready_status == 0
  for: 10m
  labels:
    severity: critical
    category: database
```

## Template-Driven Configuration System

### Resource Discovery Process
1. **Scan installed Providers**: `kubectl get providers.pkg.crossplane.io`
2. **Identify Managed Resource types**: Extract CRDs from Provider packages
3. **Generate metric configs**: Apply templates per resource category
4. **Validate metrics collection**: Confirm Prometheus scraping

### Template Categories

#### Database Resources Template
```yaml
# Covers: RDS, CloudSQL, PostgreSQL, etc.
metricTemplate: &database_template
  metrics:
    - name: ready_status
      path: status.conditions[?(@.type=="Ready")].status
    - name: synced_status  
      path: status.conditions[?(@.type=="Synced")].status
    - name: creation_time
      path: metadata.creationTimestamp
      type: timestamp
```

#### Network Resources Template  
```yaml
# Covers: VPC, Subnet, SecurityGroup, etc.
metricTemplate: &network_template
  metrics:
    - name: ready_status
      path: status.conditions[?(@.type=="Ready")].status
    - name: external_name
      path: metadata.annotations["crossplane.io/external-name"]
      type: info
```

#### Compute Resources Template
```yaml
# Covers: EC2, GKE, AKS, etc.
metricTemplate: &compute_template
  metrics:
    - name: ready_status
      path: status.conditions[?(@.type=="Ready")].status
    - name: node_count
      path: spec.forProvider.nodeCount
      type: gauge
```

## Validation and Testing

### Metric Collection Verification
```bash
# Check KSM pod logs for custom resource metrics
kubectl logs -n monitoring deployment/kube-state-metrics | grep crossplane

# Query collected metrics
curl -s http://prometheus:9090/api/v1/query?query=crossplane_resource_condition_status

# Validate all resource types have metrics
curl -s http://prometheus:9090/api/v1/label/__name__/values | grep crossplane
```

### Alert Rule Testing
```bash
# Test alert query logic
curl -s http://prometheus:9090/api/v1/query?query='crossplane_resource_condition_status{condition="Ready"}==0'

# Verify alert routing
kubectl get prometheusrule -n monitoring crossplane-alerts -o yaml
```

## Common Configuration Challenges

### 1. High Cardinality Metrics
**Problem**: Crossplane can create many short-lived resources
**Solution**: Use metric relabeling to drop high-cardinality labels
```yaml
relabel_configs:
  - source_labels: [__meta_kubernetes_pod_name]
    regex: 'temp-.*'
    action: drop
```

### 2. Missing External Names
**Problem**: Some managed resources don't populate external-name annotations
**Solution**: Extract from status fields or use alternative identifiers

### 3. Provider Version Skew
**Problem**: Different provider versions expose different metric paths
**Solution**: Version-specific templates with fallback patterns

## Automation Integration

This skill provides the knowledge foundation for:
- **Resource Template Engine** - Understands which templates to apply
- **Prometheus Observer** - Validates new metrics are collected
- **AlertManager Installer** - Ensures alerts have proper routing

The template generation and application process is handled by the Resource Template Engine skill.