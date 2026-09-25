---
category: technical
paths:
  - "**/*.yaml"
  - "**/*.yml"
---
# Skill: YAML — Patterns and Gotchas

**Context:** YAML is used for Kubernetes manifests, Helm values, CircleCI config, and Terraform yamlencode(). Each has slightly different conventions.

---

## YAML Basics (Quick Reference)

```yaml
# Strings — quotes optional unless special chars
name: my-service
full_name: "hello world"     # quote when: spaces, colons, special chars
multiline: |                 # | = literal block (preserves newlines)
  line one
  line two
folded: >                    # > = folded (newlines → spaces, good for long strings)
  this becomes one long
  string with spaces

# Lists
items:
  - alpha
  - beta
  - gamma

# Maps (objects)
config:
  host: localhost
  port: 8080

# Inline list and map
tags: [web, api, v2]
labels: {app: myapp, env: prod}

# Booleans — use true/false (not yes/no — ambiguous)
enabled: true
debug: false

# Null
value: null
# or
value: ~
```

---

## Kubernetes Manifest Structure

Every Kubernetes resource has these top-level fields:

```yaml
apiVersion: apps/v1        # API group/version — look this up for each resource type
kind: Deployment           # resource type
metadata:
  name: my-deployment      # unique within namespace
  namespace: my-namespace  # always specify, never rely on default
  labels:
    app: my-service        # used by selectors
    version: v1
spec:
  # resource-specific configuration
```

### Common resource types + their apiVersions:
| Kind | apiVersion |
|------|------------|
| Pod | v1 |
| Deployment | apps/v1 |
| Service | v1 |
| ConfigMap | v1 |
| Secret | v1 |
| ServiceAccount | v1 |
| Namespace | v1 |
| HorizontalPodAutoscaler | autoscaling/v2 |
| Ingress | networking.k8s.io/v1 |
| NetworkPolicy | networking.k8s.io/v1 |

---

## YAML in Terraform (yamlencode)

```hcl
# yamlencode() converts an HCL object to a YAML string
values = [yamlencode({
  agent = {
    resourceClasses = {
      "my-org/gke-runners" = {
        token = var.runner_token
      }
    }
    resources = {
      requests = { cpu = "100m", memory = "128Mi" }
      limits   = { cpu = "500m", memory = "512Mi" }
    }
  }
})]
```

**Why yamlencode over a separate values.yaml?**
- Terraform variables can be interpolated directly
- Single file, no YAML template management
- Type-safe — Terraform catches typos in keys

---

## CircleCI config.yml Structure

```yaml
version: 2.1

orbs:
  node: circleci/node@5.0.2     # reusable orb packages

executors:
  my-executor:
    docker:
      - image: cimg/node:18.0
    resource_class: medium

jobs:
  build:
    executor: my-executor
    steps:
      - checkout
      - run:
          name: Install dependencies
          command: npm install
      - run: npm test

  deploy-to-self-hosted:
    machine: true                      # required for self-hosted runners
    resource_class: my-org/gke-runners
    steps:
      - checkout
      - run: ./deploy.sh

workflows:
  main:
    jobs:
      - build
      - deploy-to-self-hosted:
          requires:
            - build
          filters:
            branches:
              only: main
```

---

## Common YAML Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Tab indentation | `yaml.scanner.ScannerError` | Always use spaces (2 per level) |
| Bare colon in string | Parse error | Quote the string: `"key: value"` |
| Boolean string confusion | `true`/`yes`/`on` are all truthy | Use explicit `true`/`false` |
| Trailing spaces | Diff noise | Configure editor to trim trailing whitespace |
| Implicit type conversion | `port: 8080` is int, `port: "8080"` is string | Be explicit for strings that look like numbers |
| Multi-document YAML `---` | Unexpected behavior in some tools | Use only when explicitly needed |
| Anchors + aliases abuse | Hard to read | Use sparingly; prefer explicit repetition in K8s |

---

## Helm Values Conventions

```yaml
# Good Helm values structure
image:
  repository: gcr.io/my-project/myapp
  tag: "1.2.3"      # always quote tags (can look like numbers)
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Service configuration
service:
  type: ClusterIP
  port: 80

# Feature flags
features:
  metricsEnabled: true
  tracingEnabled: false
```

---

## Diagrams — Required for All Implementations

**Every implementation in this domain MUST include a diagram.** Load the diagrams skill (`~/.claude/skills/diagrams/SKILL.md`) alongside this skill when generating diagrams.

- **Format:** draw.io XML (`.drawio`) is the primary format — save to `$CLAUDE_DIAGRAMS_DIR`
- **Style:** Use color-coded zones, priority badges, and legends per the diagrams skill guide
- **Validate:** Always run XML validation before delivering: `python3 -c "import xml.etree.ElementTree as ET; ET.parse('file.drawio')"`
- **XML safety:** Never use HTML named entities (`&amp;rarr;`, `&amp;bull;`) in raw XML — use numeric entities or ASCII
- **Notion:** Diagrams auto-import to Notion via workflow sync
