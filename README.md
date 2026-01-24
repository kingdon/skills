# Kingdon Skills

Open-source Agent Skills for rapid deployment of Kubernetes monitoring expertise. Built for teams that need to move fast without extensive training cycles.

## What This Is

A curated collection of Claude Agent Skills designed to enable entire teams to effectively monitor and operate Flux + Crossplane environments with Prometheus and AlertManager, without requiring weeks of specialized training.

## Skills Included

- **[Flux Operator](.github/skills/flux-operator)** - Validate Flux installations, debug GitOps, access Flux UI, and configure the MCP Server for AI-powered cluster debugging
- **[Author Skills](.github/skills/author-skills)** - Meta-skill for building new orthogonal agent skills
- **[Prometheus Observer](.github/skills/prometheus-observer)** - Analyze running Prometheus installations and alert states
- **[AlertManager Installer](.github/skills/alertmanager-installer)** - Install AlertManager using Flux monitoring guide patterns
- **[KSM Crossplane Adapter](.github/skills/ksm-crossplane-adapter)** - Adapt kube-state-metrics for non-Flux resources like Crossplane
- **[Resource Template Engine](.github/skills/resource-template-engine)** - Operate the templating system for onboarding new resource types
- **[Hallucination Detector](.github/skills/hallucination-detector)** - Detect and validate claims against source materials

## Quick Start

1. **Clone this repository** into your project
2. **Reload your Claude editor** to activate skills
3. **Use natural language** to activate skills:
   - "Check Flux status" → Validates GitOps and MCP server setup
   - "Check Prometheus status" → Activates monitoring analysis
   - "Install AlertManager" → Guides through installation
   - "Adapt metrics for Crossplane" → Configures resource monitoring

## Design Philosophy

**Narrative-Driven**: Skills tell stories around tools and processes, making complex knowledge accessible.

**Orthogonal**: Each skill serves a distinct purpose without overlapping functionality.

**Rapid Deployment**: Enable expertise sharing without formal training programs.

## Architecture

Uses `.github/skills/` instead of `.claude/skills/` for git-based distribution across teams. Each skill includes:

- **Progressive Disclosure**: Core guidance under 500 lines with supporting files
- **Tool Restrictions**: Appropriate permissions per skill type 
- **Embedded Examples**: Practical demonstrations over abstract templates
- **Validation Patterns**: Success criteria and quality checks

## Use Cases

- **Platform Teams**: Rapidly onboard monitoring capabilities across services
- **DevOps Engineers**: Validate and troubleshoot existing monitoring setups
- **Crossplane Operators**: Extend monitoring to custom resource types
- **Flux Users**: Implement complete monitoring stack following official guides

## Contributing

See [AGENTS.md](AGENTS.md) for agent-specific development guidelines. Use the Author Skills to create new orthogonal capabilities that complement the existing skill set.

## License

Apache 2.0 - See [LICENSE](LICENSE) for full terms.

# TDG Skills Integration

We've integrated the excellent TDG (Test-Driven Generation) skills from https://github.com/chanwit/tdg as reference implementations and for immediate use.

These skills demonstrate proper formatting and patterns that we follow in our own skill development.
