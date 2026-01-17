---
name: prometheus-observer
description: 'Observe and report on Prometheus installation state, active alerts, AlertManager configuration, and rule evaluation status'
allowed-tools: ['read_file', 'run_in_terminal', 'grep_search', 'semantic_search', 'get_terminal_output']
---

# Prometheus State Observer

I analyze running Prometheus installations to provide comprehensive reports on current alert states, configuration health, and system status without making any modifications.

## When I Activate
- "Check Prometheus status"
- "What alerts are firing?"
- "Validate AlertManager config"
- "Show Prometheus rules"
- "Prometheus health check"
- "Alert analysis"

## Core Capabilities

### 1. Alert State Analysis
- Query Prometheus API (`/api/v1/alerts`) for active/pending alerts
- Categorize alerts by severity and state
- Report alert duration and frequency patterns
- Identify which rules are triggering most frequently

### 2. AlertManager Integration Status
- Verify AlertManager connectivity via Prometheus config
- Check AlertManager API health (`/-/healthy`)
- Validate notification routing configuration
- Report on silenced alerts and inhibition rules

### 3. Rule Evaluation Health
- Query rule evaluation status (`/api/v1/rules`)
- Identify failed rule evaluations
- Report on rule evaluation latency
- Check for missing metrics in rule queries

### 4. Configuration Validation
- Parse Prometheus configuration for syntax issues
- Validate scrape target connectivity
- Check for missing labels or misconfigured jobs
- Report on retention and storage settings

## Usage Examples

### Basic Status Check
```bash
# Query active alerts
curl -s http://prometheus:9090/api/v1/alerts | jq '.data.alerts[] | {alert: .labels.alertname, state: .state, severity: .labels.severity}'

# Check AlertManager connectivity  
curl -s http://alertmanager:9093/-/healthy
```

### Advanced Analysis
```bash
# Rule evaluation metrics
curl -s http://prometheus:9090/api/v1/query?query=prometheus_rule_evaluation_failures_total | jq '.data.result[]'

# Scrape health by job
curl -s http://prometheus:9090/api/v1/query?query=up | jq '.data.result[] | {job: .metric.job, instance: .metric.instance, status: .value[1]}'
```

## Common API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/api/v1/alerts` | Active and pending alerts |
| `/api/v1/rules` | Rule evaluation status |
| `/api/v1/targets` | Scrape target health |
| `/api/v1/config` | Current configuration |
| `/-/healthy` | Health status |

## Monitoring Patterns

### Application-Specific Alerts
- Application readiness monitoring
- Deployment failure detection
- Component availability tracking

### AlertManager Routing Validation
```yaml
# Example route structure to validate
route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
```

## Troubleshooting Guide

### No Alerts Firing
- Check rule evaluation: are rules syntactically correct?
- Verify metrics availability: are scraped targets up?
- Validate time windows: are alert conditions realistic?

### AlertManager Not Receiving Alerts
- Confirm Prometheus → AlertManager configuration
- Check AlertManager logs for webhook errors
- Validate notification receiver configuration

### High Rule Evaluation Latency
- Review rule complexity and query performance
- Check for missing indices on high-cardinality metrics
- Validate scrape interval vs evaluation interval

## Integration Points

This skill provides the observational foundation for:
- **AlertManager Installer** - Understanding current state before changes
- **KSM Crossplane Adapter** - Validating new metrics are collected
- **Resource Template Engine** - Confirming new alerts activate properly