---
name: prometheus-observer
description: 'Observe and report on Prometheus installation state, active alerts, AlertManager configuration, and rule evaluation status. Trigger with /prometheus-status'
allowed-tools: ['read_file', 'run_in_terminal', 'grep_search', 'semantic_search', 'get_terminal_output']
---

# Prometheus State Observer

I analyze running Prometheus installations to provide comprehensive reports on current alert states, configuration health, and system status without making any modifications.

## Slash Command

### `/prometheus-status`
Runs the full autonomous validation workflow:
1. Verify Kubernetes cluster connectivity
2. Check Prometheus and AlertManager pods exist
3. Test port-forwarded endpoints (localhost:9090, localhost:9093)
4. Query active alerts and report status
5. Check scrape target health

**Usage**: Just type `/prometheus-status` and I will execute the validation script and report results.

**Script Verification**: Before executing, verify the script integrity:
```bash
sha256sum .github/skills/prometheus-observer/scripts/validate.sh
# Expected: check current hash after creation
```

**Execute validation**:
```bash
bash .github/skills/prometheus-observer/scripts/validate.sh
```

## When I Activate
- `/prometheus-status` (slash command)
- "Is Prometheus running?"
- "Check Prometheus status"
- "What alerts are firing?"
- "Validate AlertManager config"
- "Show Prometheus rules"
- "Prometheus health check"
- "Alert analysis"

## Port-Forward Assumptions
This skill assumes port-forwards are active or can be started:
- **Prometheus**: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &`
- **AlertManager**: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093 &`

If port-forwards are not running, the validation script will detect this and provide the commands to start them.

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

## MCP Server Accelerators

**Want faster, more comprehensive analysis?** These MCP servers provide deeper integration than manual API queries:

### Flux Operator MCP (Recommended First)
The **Flux Operator MCP Server** (`flux-operator`) provides Kubernetes resource access that complements Prometheus observation:
- Use `get_kubernetes_resources` to query PrometheusRule and ServiceMonitor objects
- Access pod logs for Prometheus/AlertManager directly
- Combined with this skill's API queries, gives complete monitoring picture

**Setup**: See flux-operator skill Step 10 for MCP server configuration.

### Prometheus MCP Server
For direct Prometheus API integration, consider:
- **[prometheus-mcp-server](https://github.com/tjhop/prometheus-mcp-server/)** (Golang) - Full API support, STDIO/SSE/HTTP transports
- **[prometheus-mcp-server](https://github.com/yanmxa/prometheus-mcp-server)** (TypeScript) - Natural language queries

These provide tool-based access to the same APIs this skill uses manually.

### Grafana MCP Server  
If you're using Grafana for visualization:
- **[mcp-grafana](https://github.com/grafana/mcp-grafana)** - Search dashboards, investigate incidents, query datasources

## Integration Points

This skill provides the observational foundation for:
- **Flux Operator** → Use MCP server for PrometheusRule resource access
- **AlertManager Installer** - Understanding current state before changes
- **KSM Crossplane Adapter** - Validating new metrics are collected
- **Resource Template Engine** - Confirming new alerts activate properly