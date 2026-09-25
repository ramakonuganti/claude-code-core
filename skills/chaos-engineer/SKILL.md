---
category: technical
name: chaos-engineer
description: Use when designing or running controlled failure experiments (pod kills, node drains, fault injection, zonal failures). Hypothesis and abort criteria first; read-only in prod by default.
paths:
  - "**/chaos/**"
  - "**/experiments/**"
  - "**/litmus/**"
  - "**/*-chaos.yaml"
metadata:
  domain: reliability
  triggers: chaos engineering, fault injection, failure testing, PDB validation, Istio fault, pod kill, node drain, recovery validation, RTO, RPO, blast radius
  role: specialist
  scope: design + execution
  related-skills: sre-engineer, kubernetes, gke
---

# Chaos Engineer

**Stack assumptions:** GKE (or equivalent) clusters across dev/stage/prod, optionally with an Istio ambient mesh in stage/prod. If no dedicated chaos tool is installed, use kubectl + Istio fault-injection CRDs + native cloud failover. A dedicated chaos tool (Litmus, Chaos Mesh) is a future option where budget/adoption allows.

## When to Use

- Validating PDB (`allowsDisruption` ≥ 1) across rollout scenarios
- Verifying an Istio ambient mesh handles a ztunnel/waypoint restart without drops
- Pre-rotation rehearsal: kill a stateful dependency's pod and verify it comes back with the current secret
- Validating an alert fires within SLO when a real failure happens
- Quarterly DR drills (zonal failover, backend regression)

## When NOT to Use

- "I just want to test if the alert works" — use a synthetic check or a monitoring test event instead
- Performance/load testing — different discipline
- Bug hunting in app code — chaos finds resilience gaps, not logic bugs

## Core Workflow

1. **State the hypothesis** in writing: "If I kill ztunnel on node X, all traffic to pods on X re-routes via fallback path within 30s with zero 5xx."
2. **Pick the smallest blast radius** that exercises the hypothesis — one pod, one node, one zone
3. **Define abort criteria** — exact metrics + threshold that say "stop, you broke prod"
4. **Get explicit user approval per command** — chaos in prod without per-command approval is a hard rule violation
5. **Set steady-state baseline** for 5–15 min before fault injection
6. **Inject the fault**, observe, document timing
7. **Restore (if needed)**, verify return to steady-state
8. **Write the postmortem** even on success — what new failure mode would surface?

## MUST DO

- Run in dev first, stage second, prod last with separate per-env approval
- Schedule a maintenance/on-call-mute window for the affected service
- Pre-announce to the team channel with start/end times
- Have a rollback command ready in a separate terminal before injection
- Capture timing: fault inject → first alert fire → recovery start → steady-state restored
- Keep blast radius ≤ 1 pod or 1 node unless hypothesis explicitly requires more
- Stop on any unexpected secondary effect (CPU spike on neighbor pod, etc.)

## MUST NOT DO

- Run chaos in prod without explicit per-command user approval
- Inject during a deploy window or active incident
- Test more than one variable at a time
- Use real customer-impacting faults when synthetic equivalents exist
- Skip the abort criteria — "we'll know it when we see it" is not abort criteria

## Common Experiments

### Pod kill (validates rolling restart + PDB)

```bash
# Steady state: pod count = N, error rate < 1%
kubectl --context=$CTX -n $NS delete pod $POD --grace-period=30
# Watch: replicaset replaces, PDB allows it, latency p95 stable, errors < 1% for 5 min
```

Hypothesis: PDB allows disruption, replicaset recovers within 60s, no 5xx surge.

### Node drain (validates multi-zone resilience)

```bash
kubectl --context=$CTX cordon $NODE
kubectl --context=$CTX drain $NODE --ignore-daemonsets --delete-emptydir-data --grace-period=60
# After: workloads landed on other nodes, no orphaned PVCs, alerts didn't fire
kubectl --context=$CTX uncordon $NODE
```

Hypothesis: PDB protects min replicas; cross-zone failover works; PV reattachment succeeds.

### Istio fault injection (delay/abort)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: chaos-${svc}
  namespace: ${ns}
spec:
  hosts: [ ${svc} ]
  http:
    - fault:
        delay:
          percentage: { value: 10 }
          fixedDelay: 5s
      route:
        - destination: { host: ${svc} }
```

Hypothesis: 10% of requests delayed 5s → upstream timeouts trigger circuit-breaker, error rate < 2%.

**Apply, observe 5 min, then immediately delete the VS**. Don't leave fault injection running.

### Stateful dependency pod kill (pre-rotation rehearsal)

```bash
kubectl --context=$CTX -n $NS delete pod ${SVC}-<stateful-dep>-0 --grace-period=30
# Verify: new pod comes up with same secret-manager-sourced password
# 3-way alignment check: pod_env_len == k8s_secret_len == secret_manager_len
```

Hypothesis: pod recovery preserves rotation chain integrity; new pod has the current password (not stale).

### Zonal failover (annual DR drill)

Scale one zone's node pool to zero on a regional cluster. Verify other zones absorb load. **Coordinate with leadership; this is a quarterly+ drill, not ad-hoc.**

## Abort Criteria Template

| Metric | Steady-state | Abort threshold |
|---|---|---|
| Error rate | < 1% | > 5% sustained 60s |
| p95 latency | < 500ms | > 2000ms sustained 60s |
| Pager alerts | 0 | any P0 page fires |
| Customer reports | 0 | any |

If any breach: STOP, restore, postmortem.

## PDB Validation Plan (sketch)

1. For each PDB tier (e.g. high-replica-count, mid, low), pick one service per tier
2. Steady-state for 10 min
3. Roll the deployment (`kubectl rollout restart`) — PDB should keep `available >= minAvailable`
4. Simultaneously evict one pod via `kubectl drain` on its node
5. Observe: did PDB block the second eviction? Did service stay up?
6. Document timings + recovery

## Reference Guide

| Topic | Reference | Load when |
|---|---|---|
| Hypothesis template | `references/hypothesis-template.md` | Designing a new experiment |
| Istio fault patterns | `references/istio-fault-injection.md` | Designing mesh-level chaos |
| Node drain runbook | `references/node-drain-runbook.md` | Running node-level chaos |
| DR drill checklist | `references/dr-drill.md` | Annual zonal/regional failover |

## Local addendum

If `ADDENDUM.md` exists in this skill's directory, read it before acting. It carries the employer-specific values this body refers to generically: org and repo names, ticket prefix, project and cluster names, incident history, and local probe commands.
