---
category: technical
name: mcp-developer
description: Use when BUILDING (not just configuring) an MCP server — defining tools/resources/prompts, choosing transport (stdio vs HTTP+SSE), structuring auth, and shipping it for Claude Code or Anthropic API consumers.
paths:
  - "**/mcp-server/**"
  - "**/*-mcp/**"
  - "**/mcp.json"
  - "**/manifest.json"
  - "**/server.py"
metadata:
  domain: ai
  triggers: MCP server, Model Context Protocol, build MCP, custom tool server, MCP transport, MCP auth, stdio MCP, HTTP MCP, FastMCP, mcp-python-sdk, mcp-typescript-sdk
  role: specialist
  scope: implementation
  related-skills: mcp, prompt-engineer, claude-api
---

# MCP Developer

Build MCP servers that expose tools, resources, and prompts to Claude Code, the Anthropic API, or other MCP-aware clients.

**Distinct from an `mcp` registration/config skill**: that kind of skill is about *registering* and *configuring* third-party MCP servers in `~/.claude.json` / `settings.json`. This one is about *authoring* a new server from scratch.

## When to Use

- Wrapping an internal tool/API as an MCP server (e.g., a cluster-ops server, a codegraph-query server)
- Adding tools that are repetitive across sessions and would benefit from being a first-class MCP tool rather than a Bash wrapper
- Building a read-only diagnostic surface for an SRE/ops agent
- Productionizing a one-off script you keep re-running

## When NOT to Use

- Configuring an existing third-party MCP — use a registration/config skill instead
- One-shot scripts; MCP overhead isn't worth it for <5 reuses
- Tools that mutate production (needs a separate authorization channel; org hard rules typically forbid this in MCP without explicit per-call confirmation)

## Decide First — Two Big Forks

### Fork 1: stdio vs HTTP+SSE transport

| Use stdio when | Use HTTP+SSE when |
|---|---|
| Single user (local Claude Code) | Multi-user (web app, claude.ai) |
| Tool runs on user's machine | Tool runs on a server |
| Auth = local creds (Keychain, gcloud ADC) | Auth = OAuth/API keys per request |
| Trivial deploy (`uv run server.py`) | Container, ingress, observability |

**Default for internal tools: stdio.** Most internal MCP servers (filesystem, github, CI, ticketing) are stdio. HTTP only when there's a real multi-user case.

### Fork 2: Python (FastMCP) vs TypeScript

- **Python (`mcp` package, FastMCP class)** — fastest to author, decorator-based. Pick this unless you have a strong TS reason.
- **TypeScript (`@modelcontextprotocol/sdk`)** — pick when wrapping a TS-only API or when the existing repo is already TS.

## Core Workflow

1. **List the tools** you want to expose. Each one needs: name, description, input schema, output, error modes.
2. **Pick transport** (Fork 1) and **language** (Fork 2)
3. **Author the server** with one tool first; verify in Claude Code via `claude mcp add <name> <command>`
4. **Add remaining tools incrementally**, each with its own quick-test
5. **Add resources** (read-only data the model can pull on demand) if relevant
6. **Add prompts** (parameterized prompt templates) if relevant
7. **Document config** in your repo's README (token storage, scope, install command)
8. **Hand to user for registration** — never edit `~/.claude.json` yourself for someone else's local setup

## MUST DO

- **One tool, one job** — `rotate_secret` and `audit_secret` are separate tools, not one with a `mode` arg
- **Tool description is a prompt** — write it like one (when to call, when NOT to call, preconditions)
- **JSON Schema for inputs** — strict types, enums where possible, required fields explicit
- **Wrap secrets in keychain or env-var** — never hardcode; for stdio, use a wrapper script that fetches the secret from an OS credential store then `exec`s the real server
- **Return structured errors** — `{"error": "auth_failed", "message": "..."}` not bare strings; lets the model recover
- **Idempotent reads** — list/get/search must be safe to call multiple times
- **Pin SDK version** in `pyproject.toml`/`package.json`
- **Smoke-test outside Claude** — `mcp dev server.py` (FastMCP includes a CLI tester); don't make Claude Code your first test harness

## MUST NOT DO

- Mutate prod from an MCP tool without explicit per-call user confirmation in the model's flow
- Expose `eval`, `exec`, or arbitrary-shell tools — defeats the schema-typed contract
- Block the stdio loop on long ops — use async; MCP clients have request timeouts
- Trust input — same XSS/injection rules as a web API; sanitize before exec/SQL
- Ship without a README documenting auth + scope + install
- Mix transport modes — pick stdio OR http, not both in one binary

## FastMCP Skeleton (Python)

```python
# server.py
from mcp.server.fastmcp import FastMCP
import os, json

mcp = FastMCP("example-graph")  # server name shown in Claude

@mcp.tool()
def search_callers(symbol: str) -> dict:
    """Find all callers of a symbol across the org's repos via the codegraph DB.

    Use this when the user asks "where is X called from?" or "what depends on Y?".
    Returns a list of (repo, file, line, caller_symbol) tuples. Capped at 100 results.
    """
    db = os.path.expanduser("~/.claude/codegraph/example.db")
    # ... query ...
    return {"results": [...]}

@mcp.resource("graph://stats")
def graph_stats() -> str:
    """Current node + edge counts for the codegraph DB."""
    return json.dumps({"nodes": 71219, "edges": 136160})

if __name__ == "__main__":
    mcp.run(transport="stdio")
```

Register:
```bash
claude mcp add example-graph -- uv run --directory ~/Repos/example-graph-mcp server.py
```

## Keychain Wrapper Pattern (stdio + secrets)

```bash
# ~/.claude/bin/example-graph-mcp.sh
#!/bin/bash
set -euo pipefail
TOKEN=$(security find-generic-password -s 'example-graph-token' -w)
export EXAMPLE_TOKEN="$TOKEN"
exec /usr/local/bin/uv run --directory "$HOME/Repos/example-graph-mcp" server.py
```

Register the wrapper, not the raw command:
```bash
claude mcp add example-graph -- ~/.claude/bin/example-graph-mcp.sh
```

This pattern (fetch secret from OS keychain in a wrapper script, `exec` the real server, register the wrapper rather than the raw command) generalizes to any stdio MCP server that needs a token.

## Reference Guide

| Topic | Reference | Load when |
|---|---|---|
| FastMCP idioms | `references/fastmcp-patterns.md` | Building Python MCP server |
| TypeScript SDK idioms | `references/ts-sdk-patterns.md` | Building TS MCP server |
| HTTP+SSE transport | `references/http-transport.md` | Multi-user / remote server |
| Auth patterns | `references/auth-patterns.md` | OAuth, keychain, API keys |
| Testing harness | `references/test-harness.md` | Setting up MCP server tests |

## Companion

- an `mcp` registration/config skill — for registration + best practices on the harness side
- `prompt-engineer` skill — tool descriptions are prompts; cross-apply
- `claude-api` skill — if integrating MCP server output back into a Claude API app

## Local addendum

If `ADDENDUM.md` exists in this skill's directory, read it before acting. It carries the employer-specific values this body refers to generically: org and repo names, ticket prefix, project and cluster names, incident history, and local probe commands.
