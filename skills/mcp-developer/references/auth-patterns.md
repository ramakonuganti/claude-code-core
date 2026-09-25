# MCP Auth Patterns

Auth design depends on transport. Pick the simplest that meets the threat model.

## stdio — local credentials

The MCP server inherits the user's environment. Three patterns:

### 1. OS Keychain (macOS default)

```bash
# Store once
security add-generic-password -s 'example-graph-token' -a "$USER" -w "<token>"

# Wrapper fetches at exec time
TOKEN=$(security find-generic-password -s 'example-graph-token' -w)
export EXAMPLE_TOKEN="$TOKEN"
exec uv run server.py
```

**Never** put a literal token in an env-var entry inside `~/.claude.json` (e.g. `-e EXAMPLE_TOKEN=<literal>`) — fetch it at exec time in a wrapper script instead.

### 2. gcloud ADC (Application Default Credentials)

```python
from google.auth import default
creds, _ = default()
```

Works for any GCP API. User runs `gcloud auth application-default login` once. No token in keychain needed. Best for read-only GCP-resource MCPs.

### 3. kubeconfig

```python
from kubernetes import config
config.load_kube_config()
```

Inherits `kubectl` context. Combine with read-only RBAC for the safest cluster MCP.

## HTTP — per-request auth

Pick one, don't mix:

### OAuth 2.0 Authorization Code

For human users via claude.ai. MCP server is the resource server; identity provider issues short-lived access tokens. Refresh tokens stored encrypted at rest.

Spec: https://spec.modelcontextprotocol.io/specification/2025-03-26/basic/authorization/

### API key (Bearer)

For service-to-service. Format: `Authorization: Bearer <opaque-key>`. Issue per-tenant; rotate via a secrets manager; revoke fast on suspected leak. Never log the key.

### mTLS

Internal-only servers. Workload identity on the caller side, cert-manager-issued cert on the server side. No tokens in flight, but cert rotation is real ops work.

## Scoping (least privilege)

Every MCP server should expose **only the surface a single user role needs**.

- `example-graph-readonly` (any user) — search/list/callers
- `example-graph-admin` (platform team only) — re-bootstrap, rule changes
- Two servers, two registrations. Don't gate inside a single server with role checks if you can split by registration.

## Audit trail

For any MCP that touches infra:

- Every tool call → a structured log line to your log sink
- Include: tool, user (email or local `$USER`), input hash (not raw input — may contain secrets), output status, latency
- Set a retention policy and a longer-term sink (e.g. a warehouse table) if compliance requires it

## What you should NEVER do

- Hardcode tokens in a client config file — even for "just testing", because the file gets backed up, synced to dotfiles, copy-pasted into chat
- Log tool inputs raw (may contain secrets the user pasted)
- Implement your own JWT verification — use a library
- Trust a user's account email as authorization without binding it to an IdP-issued token
- Reuse one API key across dev/stage/prod
