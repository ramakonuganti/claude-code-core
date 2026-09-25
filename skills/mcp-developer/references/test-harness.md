# MCP Server Test Harness

Three test layers, each cheap, each catches a different bug class.

## Layer 1: Unit (pure function)

Tools are just functions decorated with `@mcp.tool()`. Test the underlying function directly:

```python
# server.py
@mcp.tool()
def search_callers(symbol: str) -> list[dict]:
    return _search_callers_impl(symbol)

def _search_callers_impl(symbol: str) -> list[dict]:
    ...

# tests/test_callers.py
from server import _search_callers_impl

def test_search_callers_empty():
    assert _search_callers_impl("nonexistent::symbol") == []

def test_search_callers_caps_at_100():
    hits = _search_callers_impl("common::Logger")
    assert len(hits) <= 100
```

Split decorator from implementation. The decorator-bound version isn't directly callable in tests cleanly.

## Layer 2: Protocol (the FastMCP CLI)

```bash
mcp dev server.py
```

Interactive REPL. Confirms:
- Tool registration succeeds
- Schema is valid JSON Schema
- Tool returns serializable output
- Resources/prompts wire up

Run before every commit if you changed schemas.

## Layer 3: End-to-end via Claude Code

Add a test registration:

```bash
claude mcp add test-example-graph -- uv run --directory $(pwd) server.py
```

Then spin up a session and ask the model to call each tool with representative input. Verify:
- Description is enough for the model to pick the right tool
- Input is filled correctly
- Output is parsed correctly into the next reasoning step
- Errors recover gracefully (force one — wrong env, missing arg)

If the model misuses a tool, that's a description bug, not a model bug. Tighten the description.

## Regression set

Every bug fixed in prod becomes a test:

```python
def test_regression_001_unicode_symbol():
    # Bug: symbols with `::` were truncated at first colon
    hits = _search_callers_impl("std::collections::HashMap")
    assert hits  # was [] before fix
```

## CI

A CI workflow that runs `pytest` + `mcp dev --validate server.py`:

```yaml
test-mcp:
  docker:
    - image: cimg/python:3.12
  steps:
    - checkout
    - run: pip install -e .[dev]
    - run: pytest -v
    - run: mcp dev --validate server.py
```

Pre-merge gate. Don't rely on local `mcp dev` runs only — they drift.

## Manual smoke checklist before release

- [ ] Every tool tested with valid input → expected output
- [ ] Every tool tested with invalid input → structured error (not raw exception)
- [ ] Auth wrapper tested (credential-store miss → graceful failure, not crash)
- [ ] Resource fetch tested (cache hit + miss)
- [ ] Long-running tool cancelled mid-flight → no orphan process
- [ ] README install steps followed from a clean machine

## Anti-patterns

- ❌ Testing only via Claude Code (slow, expensive, flaky)
- ❌ No regression tests (bugs come back)
- ❌ Tests that hit prod (use a test fixture or local DB)
- ❌ Skipping the `mcp dev --validate` step (schema drift caught here)
