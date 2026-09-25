# TypeScript SDK Patterns

Use `@modelcontextprotocol/sdk` when wrapping TS-only APIs or when the host repo is already TS. Otherwise prefer FastMCP/Python.

## Project layout

```
example-svc-mcp/
  package.json        # @modelcontextprotocol/sdk pinned
  tsconfig.json
  src/
    server.ts
    tools/
      list-services.ts
    schemas.ts        # zod schemas
  README.md
```

## Server skeleton

```ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

const server = new Server(
  { name: "example-svc", version: "0.1.0" },
  { capabilities: { tools: {} } },
);

const ListServicesInput = z.object({
  env: z.enum(["dev", "stage", "prod"]),
});

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [{
    name: "list_services",
    description: "List services in the given env...",
    inputSchema: zodToJsonSchema(ListServicesInput),
  }],
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  if (req.params.name === "list_services") {
    const input = ListServicesInput.parse(req.params.arguments);
    return { content: [{ type: "text", text: JSON.stringify(await listServices(input.env)) }] };
  }
  throw new Error(`Unknown tool: ${req.params.name}`);
});

await server.connect(new StdioServerTransport());
```

## zod → JSON Schema

Use `zod-to-json-schema` to derive `inputSchema` automatically; never hand-author and let it drift from the runtime validator.

## Build + run

```json
{
  "scripts": {
    "build": "tsc",
    "start": "node dist/server.js",
    "dev": "tsx src/server.ts"
  }
}
```

Register the built artifact, not `tsx`:

```bash
claude mcp add example-svc -- node /path/to/example-svc-mcp/dist/server.js
```

## Pinning

```json
{
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.2.0",
    "zod": "^3.23.0",
    "zod-to-json-schema": "^3.23.0"
  }
}
```

## Why pick TS over Python

- Existing repo is TS (tooling, service rewrite candidates)
- Need to consume a TS-only SDK (e.g., a vendor's typed client)
- Bun runtime requirement

Otherwise default to FastMCP for the lower line count.
