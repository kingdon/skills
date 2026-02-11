---
name: github-mcp-setup
description: Configure GitHub MCP server using gh CLI with Docker. Enables AI agents to interact with GitHub repositories, PRs, issues, and code search. Trigger with /github-mcp or "setup GitHub MCP"
allowed-tools: ['read_file', 'create_file', 'replace_string_in_file', 'run_in_terminal', 'list_dir']
---

# GitHub MCP Server Setup

Configure the GitHub MCP server for VS Code Copilot using the `gh` CLI extension with Docker.

## Quick Reference

| Requirement | Details |
|-------------|---------|
| **Docker** | OrbStack, Docker Desktop, or docker daemon |
| **gh CLI** | `brew install gh` or [cli.github.com](https://cli.github.com) |
| **gh-mcp extension** | `gh extension install shuymn/gh-mcp` |
| **Authentication** | Uses existing `gh auth` credentials |

## Prerequisites Check

```bash
# 1. Verify gh CLI installed and authenticated
gh auth status

# 2. Verify Docker is running (OrbStack, Docker Desktop, etc.)
docker info > /dev/null 2>&1 && echo "Docker OK" || echo "Docker NOT running"

# 3. Check if gh-mcp extension installed
gh extension list | grep mcp
```

## Installation

### Step 1: Install gh-mcp Extension

```bash
gh extension install shuymn/gh-mcp
```

This installs the `shuymn/gh-mcp` extension which wraps the official `ghcr.io/github/github-mcp-server` Docker image.

### Step 2: Test the Extension

```bash
gh mcp --help 2>&1 | head -15
```

**Expected output:**
```
time=... level=INFO msg="🔐 Retrieving GitHub credentials..."
time=... level=INFO msg="✅ Authenticated" host=https://github.com
time=... level=INFO msg="🐳 Connecting to Docker..."
time=... level=INFO msg="✅ Docker client connected"
time=... level=INFO msg="📦 Checking for MCP server image..."
time=... level=INFO msg="✓ Image found locally"
time=... level=INFO msg="✅ Ready! Starting MCP server..."
```

### Step 3: Configure VS Code MCP

Add to `~/Library/Application Support/Code/User/mcp.json`:

```json
{
  "servers": {
    "github": {
      "type": "stdio",
      "command": "gh",
      "args": ["mcp"],
      "env": {}
    }
  }
}
```

### Step 4: Reload VS Code

Either:
- Restart VS Code
- Command Palette → "MCP: List Servers" → restart the github server

## Verification

After setup, ask Claude: "Who am I on GitHub?"

The agent should be able to use `mcp_github_get_me` and return your GitHub profile.

## Docker Dependency: Kill Switch

**Important**: The GitHub MCP server requires Docker to run.

This can be used as a **deliberate kill switch**:
- **To disable GitHub MCP**: Quit Docker/OrbStack
- **To re-enable**: Start Docker/OrbStack

This is useful when:
- You want to prevent accidental repository modifications
- You're working offline
- You want to reduce resource usage
- You need to ensure the agent cannot access GitHub

### Error When Docker Not Running

```
level=ERROR msg=Error err="failed to inspect image: Cannot connect to 
the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?"
```

This is expected behavior when Docker is stopped.

## Troubleshooting

### Authentication Issues

```bash
# Check current auth
gh auth status

# Re-authenticate if needed
gh auth login
```

### MCP Server Version

```bash
# Check installed extension
gh extension list

# Upgrade extension
gh extension upgrade shuymn/gh-mcp
```

The Docker image version is managed by the extension. Currently using `github-mcp-server v0.30.1`.

### Image Pull Issues

The first run may take longer as it pulls the Docker image:
```bash
# Force pull latest image
docker pull ghcr.io/github/github-mcp-server:latest
```

## Alternative: Copilot-Hosted MCP (Not Recommended)

VS Code Copilot can use a hosted MCP server, but authentication issues are common:

```json
{
  "servers": {
    "github/github-mcp-server": {
      "type": "http", 
      "url": "https://api.githubcopilot.com/mcp/"
    }
  }
}
```

This often returns 401 errors. The `gh mcp` approach is more reliable.

## Capabilities

Once configured, the agent can:

| Capability | Tool Prefix |
|------------|-------------|
| Repository operations | `mcp_github_*` |
| Pull request management | `mcp_github_pull_request_*` |
| Issue tracking | `mcp_github_issue_*` |
| Code search | `mcp_github_search_code` |
| User/team lookup | `mcp_github_get_me`, `mcp_github_search_users` |
| Branch/commit operations | `mcp_github_list_commits`, `mcp_github_create_branch` |

## Security Considerations

- Uses your existing `gh auth` token (OAuth or PAT)
- Token permissions determine what the agent can do
- The Docker container runs with your credentials
- Consider using a read-only PAT for sensitive environments

## Expected Failure Modes

| Symptom | Cause | Resolution |
|---------|-------|------------|
| "Cannot connect to Docker daemon" | Docker not running | Start OrbStack/Docker Desktop |
| "gh: command not found" | gh CLI not installed | `brew install gh` |
| "gh mcp: command not found" | Extension not installed | `gh extension install shuymn/gh-mcp` |
| 401 Unauthorized | Token expired | `gh auth refresh` |
| "rate limit exceeded" | Too many API calls | Wait or use different token |

## SHA256 Canary

```
echo "github-mcp-setup skill loaded" | sha256sum
# f8a7c3d2e1b0... (first invocation marker)
```

If you see this hash mentioned by the agent, the skill was properly invoked and read.

## Related Skills

- [flux-operator](../flux-operator/SKILL.md) - Uses Flux MCP for cluster debugging
- [author-skills](../author-skills/SKILL.md) - Documents MCP awareness patterns
