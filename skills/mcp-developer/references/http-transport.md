# HTTP+SSE Transport

Use HTTP only when stdio doesn't fit: multi-user, runs on a server, claude.ai or web-app consumer.

## When NOT to bother

- Single user on a laptop → stdio
- Tool needs local creds (gcloud ADC, kubeconfig, secrets via workload identity) → stdio
- You haven't profiled stdio first → stdio

If every existing internal MCP server is already stdio, HTTP only makes sense for a new server when it must be exposed to remote/non-local users — confirm that's actually on the roadmap before building it.

## FastMCP HTTP

```python
mcp = FastMCP("example-rotation")

@mcp.tool()
def audit(env: str) -> dict: ...

if __name__ == "__main__":
    mcp.run(transport="streamable-http", host="0.0.0.0", port=8080)
```

`streamable-http` is the current spec (replaces older SSE-only). The old `transport="sse"` still works but is being deprecated.

## Deployment shape

```
[claude.ai] --HTTPS--> [Load balancer] --> [Cloud Run / GKE Service] --> [MCP server]
                                                |
                                                v
                                        [DB / secrets manager / logs]
```

A managed single-binary runtime (e.g. Cloud Run) is the right starting point for a single-binary HTTP MCP. A full cluster (GKE) only if you need sidecars or shared cluster resources.

## Auth

stdio MCP authenticates via inherited env (the wrapper script). HTTP MCP must authenticate every request:

- **OAuth 2.0 Authorization Code** — for human users via claude.ai. Issue tokens scoped to one server.
- **API key** in `Authorization: Bearer <key>` — for service-to-service. Rotate via a secrets manager, never hardcode.
- **mTLS** — internal-only servers; pair with workload identity.

Never accept anonymous traffic. MCP servers expose tool surface area; assume any caller will try to abuse it.

## Observability

- Log every tool call: `{tool, user, input_hash, latency, status}` — JSON to stdout, sink to your log platform
- APM agent → traces to your existing dashboard
- Page on 5xx rate > threshold — same pattern as any other production service
- Cap per-user request rate; cap per-tool resource use (DB row count, output size)

## Cost watchpoints

- LLM-driven traffic is bursty; autoscaler min replicas matter
- Tool fan-out: one user prompt → N tool calls per turn → multiply by concurrent users
- Don't expose unbounded queries — every tool needs a `limit` cap with a sane default

## Spec links

- streamable-http transport: https://spec.modelcontextprotocol.io/specification/2025-03-26/basic/transports/
- OAuth flow for MCP: https://spec.modelcontextprotocol.io/specification/2025-03-26/basic/authorization/
