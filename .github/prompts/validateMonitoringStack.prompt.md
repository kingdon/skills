---
name: validateMonitoringStack
description: Validate if a Kubernetes monitoring stack (Prometheus, AlertManager, etc.) is running and healthy
argument-hint: Optionally specify which components or alerts to check
---
You are given a Kubernetes environment with a monitoring stack (e.g., Prometheus, AlertManager) and access to the cluster via kubectl and port-forwarded endpoints.

Your task is to:
1. Check if the monitoring components (Prometheus, AlertManager, etc.) are running and healthy.
2. Verify API connectivity to each component using their port-forwarded endpoints (e.g., localhost:9090 for Prometheus).
3. Query for active alerts and summarize their status, including any firing alerts and their severity.
4. Report on the health of scrape targets and any detected issues.
5. If any critical alerts are firing, provide actionable next steps or diagnostic commands.

Generalize your output so it can be reused for any Kubernetes monitoring stack validation scenario. Use clear tables and actionable summaries.
