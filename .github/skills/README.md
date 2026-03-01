# Agent Skills for Mecris

This directory contains a collection of custom skills designed for the Gemini CLI and Claude Code agents operating within the Mecris environment. These skills act as modular, expert instructions that provide the agent with specialized knowledge, operational workflows, and tool integrations for a variety of tasks.

## Acknowledgements

Much of the thinking that prompted these skills to be developed in the open, on my own time, happened while on paid time, working for **Navteca, LLC.** as a DevOps Engineer on the SMDC project (also known internally as the Science Cloud Infrastructure Project, or SCIP), building Science Cloud. All rights reserved.

Many of these skills are sourced from [github.com/kingdon/skills](https://github.com/kingdon/skills).

A select few skills, particularly centered around Test-Driven Development, are sourced from [chanwit/tdg: Test-Driven Generation for Claude Code](https://github.com/chanwit/tdg).

## Available Skills

All skills have been carefully designed using the `author-skills` skill to ensure they remain orthogonal to one another, preventing overlap in responsibilities.

1. **alertmanager-installer**: Install and configure AlertManager following monitoring guide patterns and best practices for Kubernetes environments.
2. **Atomic Commit** (TDG): Helps create clean, atomic commits by analyzing changes, detecting mixed concerns, and ensuring each commit is a complete unit of work.
3. **author-skills**: Write and maintain `SKILL.md` files for the user using all available wisdom and documented guidance.
4. **crossplane-provider-surgery**: Diagnose and repair Crossplane Kubernetes & Helm provider connectivity issues in EKS compositions.
5. **flux-operator**: Validate Flux Operator installations, debug GitOps connectivity issues, access the Flux UI, and configure the MCP server.
6. **github-mcp-setup**: Configure GitHub MCP server using `gh` CLI with Docker. Enables AI agents to interact with GitHub repositories, PRs, issues, and code search.
7. **hallucination-detector**: Detect potential hallucinations by tracing claims back to source materials and validating conclusions.
8. **ksm-crossplane-adapter**: Adapt kube-state-metrics configuration for monitoring non-Flux resources like Crossplane Managed Resources and Compositions.
9. **oidc-kubeconfig-setup**: Configure kubectl access to Kubernetes clusters with OIDC authentication (Dex, Azure AD, Keycloak).
10. **pihole-sync**: Validate dual-subnet Pi-Hole DNS topology, debug Gravity DB replication, and test DNS failover.
11. **postmortem-author**: Generate Sunkworks-style post-mortem reports with timeline reconstruction, failure pattern recognition, and recovery playbooks.
12. **prometheus-observer**: Observe and report on Prometheus installation state, active alerts, AlertManager configuration, and rule evaluation status.
13. **resource-template-engine**: Operate the templating system for onboarding new Crossplane resource types with automated metric configuration.
14. **sos-emergency**: Emergency Kubernetes cluster recovery, Talos reset procedures, Synology Container Manager recovery, and graceful shutdown protocols.
15. **start-blasting**: Pragmatic task execution that chooses the fastest path for mundane tasks that humans are slow at.
16. **TDG Test-Driven Generation**: Uses TDD techniques to generate tests and code in Red-Green-Refactor loops.
17. **ticket-author**: Author work tickets in a standard format with Business Value, Requirements, Deliverables, and Notes sections.
18. **vind-operator**: Validate Vind (lightweight Kubernetes) cluster creation, migrate from Kind to Vind, and perform cross-architecture testing.

## Model Context Protocol (MCP) Integrations

Several of these skills and the broader Mecris agent rely on the Model Context Protocol (MCP) to interact with external tools (like GitHub, SQLite, etc.). The MCP server is configured in a few places across the project. 

For detailed information on how MCP is configured and used within Mecris, please see the [MCP Configurations Document](../../docs/MCP_CONFIGURATIONS.md).
