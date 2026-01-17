---
name: alertmanager-installer
description: 'Install and configure AlertManager following fluxcd.io monitoring guide patterns and best practices for Kubernetes environments'
allowed-tools: ['read_file', 'create_file', 'replace_string_in_file', 'run_in_terminal', 'semantic_search']
---

# AlertManager Installation Expert

I install and configure AlertManager using Flux monitoring patterns from the official 5-part fluxcd.io monitoring guide, ensuring proper integration with existing Prometheus and Kubernetes infrastructure.

## When I Activate
- "Install AlertManager"
- "Set up monitoring stack"
- "Configure Flux alerting"
- "Deploy AlertManager with Flux"
- "Monitoring guide setup"

## 5-Part Flux Monitoring Guide Knowledge

### Part 1: Monitoring Stack Setup
**Purpose**: Establish the foundational monitoring infrastructure
**Key Components**: 
- Prometheus Operator via Helm
- ServiceMonitors for automatic discovery
- Namespace and RBAC configuration

```yaml
# Example Prometheus Operator HelmRelease
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: prometheus-stack
  namespace: monitoring
spec:
  chart:
    spec:
      chart: kube-prometheus-stack
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
```

### Part 2: AlertManager Configuration
**Purpose**: Configure notification routing and receiver setup
**Key Concepts**:
- Route hierarchy and grouping
- Inhibition rules for alert storm prevention
- Multiple receiver types (webhook, email, slack)

```yaml
# AlertManager configuration structure
alertmanager:
  config:
    global:
      smtp_smarthost: 'smtp.example.com:587'
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 5m
      repeat_interval: 12h
      receiver: default-receiver
    receivers:
      - name: default-receiver
        webhook_configs:
          - url: 'http://webhook-service/alerts'
```

### Part 3: Custom Alerts for Flux Components
**Purpose**: Monitor Flux-specific resources and state changes
**Alert Categories**:
- Source readiness (GitRepository, Bucket, HelmRepository)
- Kustomization deployment status
- Helm release health

```yaml
# Example Flux alert rule
groups:
  - name: flux
    rules:
      - alert: FluxComponentNotReady
        expr: gotk_reconcile_condition{type="Ready",status="False"} == 1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Flux component {{ $labels.kind }}/{{ $labels.name }} not ready"
```

### Part 4: Application-Level Monitoring
**Purpose**: Extend monitoring to application workloads
**Integration Points**:
- PodMonitors for application metrics
- ServiceMonitors for service discovery
- Custom recording rules for SLIs

### Part 5: Grafana Dashboard Integration  
**Purpose**: Visualization and operational dashboards
**Components**:
- Pre-configured Flux dashboards
- Alert status visualization
- Resource utilization tracking

## Installation Process

### 1. Prerequisites Validation
```bash
# Check existing Prometheus installation
kubectl get prometheus -A
kubectl get servicemonitors -A

# Validate RBAC permissions
kubectl auth can-i create alertmanagers
kubectl auth can-i create servicemonitors
```

### 2. Namespace Preparation
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    monitoring: enabled
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: alertmanager-reader
rules:
  - apiGroups: [""]
    resources: ["nodes", "services", "endpoints", "pods"]
    verbs: ["get", "list", "watch"]
```

### 3. AlertManager Deployment
```yaml
# Flux-managed AlertManager
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  interval: 5m
  chart:
    spec:
      chart: alertmanager
      version: '0.25.x'
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
        namespace: monitoring
  values:
    config:
      global:
        resolve_timeout: 5m
      route:
        group_by: ['alertname']
        group_wait: 10s
        group_interval: 10s
        repeat_interval: 1h
        receiver: 'default'
      receivers:
        - name: 'default'
          webhook_configs:
            - url: 'http://webhook-service/webhook'
```

### 4. Service Integration
```yaml
# ServiceMonitor for AlertManager itself
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: alertmanager
  endpoints:
    - port: web
      interval: 30s
      path: /metrics
```

## Configuration Patterns

### Notification Routing Strategy
1. **Critical Alerts**: Immediate notification (PagerDuty, phone)
2. **Warning Alerts**: Grouped notifications (Slack, email)
3. **Info Alerts**: Dashboard-only, no active notification

### Inhibition Rules
```yaml
# Prevent alert storm during cluster issues
inhibit_rules:
  - source_match:
      alertname: 'KubeNodeNotReady'
    target_match:
      alertname: 'KubePodNotReady'
    equal: ['node']
```

### Silencing Patterns
- Maintenance windows via API
- Temporary environment silencing
- Development namespace exclusions

## Validation Steps

### 1. Health Checks
```bash
# AlertManager API health
curl http://alertmanager:9093/-/healthy

# Configuration reload
curl -X POST http://alertmanager:9093/-/reload
```

### 2. Alert Delivery Test
```bash
# Send test alert
curl -X POST http://alertmanager:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{"labels":{"alertname":"test","severity":"warning"}}]'
```

### 3. Prometheus Integration
```bash
# Verify Prometheus can reach AlertManager
curl http://prometheus:9090/api/v1/query?query=alertmanager_up
```

## Troubleshooting Guide

### Common Issues
- **Config validation failures**: YAML syntax, receiver validation
- **Network connectivity**: Service discovery, DNS resolution  
- **Authentication**: Webhook endpoints, SMTP credentials
- **Alert routing**: Group_by conflicts, route hierarchy

### Debug Commands
```bash
# Check AlertManager logs
kubectl logs -n monitoring deployment/alertmanager

# Validate configuration  
amtool config check --config=/etc/alertmanager/alertmanager.yml

# Test routing
amtool config routes test --config.file=/etc/alertmanager/alertmanager.yml
```

## Integration Points

This skill enables:
- **Prometheus Observer** - Validates installation success
- **KSM Crossplane Adapter** - Provides alerting foundation for custom metrics
- **Resource Template Engine** - Ensures new alerts have proper notification routing