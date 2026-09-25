# FastMCP Patterns (Python)

`mcp.server.fastmcp.FastMCP` is the decorator-based authoring API. Pick this for internal servers unless TS is forced.

## Project layout

```
example-graph-mcp/
  pyproject.toml      # mcp[cli]>=1.2 pinned
  server.py           # entry point
  src/
    db.py             # codegraph DB query helpers
    schemas.py        # pydantic models for tool I/O
  tests/
    test_tools.py
  README.md           # auth + install + scope
```

## Tools

```python
from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field

mcp = FastMCP("example-graph")

class CallerHit(BaseModel):
    repo: str
    file: str
    line: int
    caller: str

@mcp.tool()
def search_callers(symbol: str = Field(..., description="Fully-qualified symbol")) -> list[CallerHit]:
    """Find all callers of `symbol` across the org's repos.

    Use when the user asks "where is X called from?" or "who depends on Y?".
    Returns up to 100 hits sorted by repo. Cross-repo edges only.
    """
    ...
```

Pydantic types make schemas self-document. Don't hand-write JSON Schema unless you need an exotic constraint.

## Resources (read-only)

```python
@mcp.resource("graph://stats")
def graph_stats() -> str:
    """Live counts for the codegraph DB."""
    return json.dumps({"nodes": 71219, "edges": 136160})
```

URIs are model-visible — keep schemes meaningful (`graph://`, `secret://`, `incident://`).

## Prompts (parameterized templates)

```python
@mcp.prompt()
def incident_triage(incident_id: str) -> list[dict]:
    """Triage prompt for an incident — pulls paging context + recent events."""
    return [
        {"role": "user", "content": f"Triage incident {incident_id}. Pull logs from last 1h."}
    ]
```

Prompts are slash-command-like for the user; resources are model-pulled.

## Async + cancellation

```python
@mcp.tool()
async def slow_audit(env: str) -> dict:
    async with httpx.AsyncClient(timeout=10) as client:
        ...
```

MCP clients enforce request timeouts (~30s default). Use async; never block stdio.

## Errors

Return structured failures, not exceptions:

```python
return {"error": "auth_failed", "message": "token rejected", "retry": False}
```

## Smoke test

```bash
mcp dev server.py    # interactive tool tester
```

Don't make Claude Code your first test harness.

## Pinning

```toml
[project]
dependencies = ["mcp[cli]>=1.2,<2"]
```

MCP protocol versions move. Pin major; review on each minor bump.
