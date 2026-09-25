# Node Drain — Chaos Runbook

Validates: PDB `allowsDisruption` ≥ 1, cross-zone failover, PV reattachment, pod-anti-affinity.

## Pre-flight

```bash
# Confirm regional cluster (multi-zone)
kubectl --context=$CTX get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.topology\.kubernetes\.io/zone}{"\n"}{end}' | sort -k2

# Pick a node with at least one workload of each tier
NODE=<chosen node>
kubectl --context=$CTX get pods --all-namespaces --field-selector=spec.nodeName=$NODE
```

## Cordon then drain

```bash
# Cordon: prevents new scheduling but doesn't evict
kubectl --context=$CTX cordon $NODE

# Capture steady state (5 min) BEFORE drain

# Drain: evicts pods respecting PDBs
kubectl --context=$CTX drain $NODE \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=60 \
  --timeout=10m
```

If drain hangs on a PDB violation, the PDB is doing its job. **Do not** force with `--disable-eviction`. Stop, document the PDB, restore.

## Observe during drain

- Pods land on other nodes within their zone first; cross-zone if needed
- StatefulSet pods get re-attached to their PVC on the new node
- HPAs may bump replica count if utilization spikes
- Monitoring shows `restartCount` increment on affected containers

## Restore

```bash
kubectl --context=$CTX uncordon $NODE
```

Verify cluster autoscaler decisions don't terminate the node post-drain (it might be empty + idle for a while then GC'd; that's fine).

## Abort criteria specific to drain

| Symptom | Action |
|---|---|
| Drain blocked by PDB longer than 5 min | STOP — investigate PDB; do NOT force |
| Pod stuck `Pending` for 2 min on other nodes | STOP — likely resource pressure or anti-affinity collision |
| PVC `Pending` reattach for 2 min | STOP — PV zone constraint may not match new node zone |
| Service alerts fire | STOP — drain already breached SLO |

## Post-experiment artifacts

- `kubectl get events -n $NS --field-selector involvedObject.name=$NODE` — drain timeline
- `kubectl describe pod $POD -n $NS` (for any pod that took longer than expected)
- Monitoring dashboard screenshot covering steady-state → drain → recovery

## PDB Validation by Tier (generic pattern)

Define PDB tiers by replica count and expected drain impact, e.g.:
- High-replica tier (6+ replicas): expect drain to complete with no measurable impact
- Mid-replica tier (3–5 replicas): expect 1 brief p95 latency bump, no error spike
- Low-replica tier (2 replicas): expect PDB to allow exactly 1 disruption; second eviction blocks until first pod ready

See `ADDENDUM.md` for this org's actual tier definitions and the active PDB rollout ticket this runbook validates.
