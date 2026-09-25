# Istio Fault Injection

**Stack:** Istio ambient mesh in stage/prod. Use VirtualService fault for L7 testing on services already running with a sidecar or waypoint. Always apply, observe, immediately delete — never leave fault running.

## Delay

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: chaos-example-service-delay
  namespace: production
spec:
  hosts: [example-service]
  http:
    - fault:
        delay:
          percentage:
            value: 10        # 10% of requests delayed
          fixedDelay: 5s
      route:
        - destination:
            host: example-service
```

Hypothesis: 10% delay 5s → upstream callers' p95 spikes; circuit breakers / retry budgets engage; error rate stays < 2%.

## Abort

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: chaos-example-service-abort
  namespace: production
spec:
  hosts: [example-service]
  http:
    - fault:
        abort:
          percentage:
            value: 5         # 5% of requests fail
          httpStatus: 503
      route:
        - destination:
            host: example-service
```

Hypothesis: 5% 503 → callers' retry budgets compensate; SLO budget burns < 10% in 1h.

## Apply / Observe / Delete

```bash
# Apply
kubectl --context=$CTX apply -f /tmp/chaos-vs.yaml

# Observe for fixed window (set a timer, don't eyeball)
sleep 300

# DELETE — even if observation isn't done, the steady-state must be restored
kubectl --context=$CTX delete -f /tmp/chaos-vs.yaml
```

**Common mistake:** leaving the VS in place during a debug session. The mesh keeps faulting until you remove it.

## Ambient mesh notes

In ambient mode (no sidecars), L7 fault injection requires a **waypoint proxy** for the target service. If no waypoint, only L4 features apply (mTLS, AuthZ) — VirtualService `http.fault` is a no-op. Confirm the service has a waypoint:

```bash
kubectl --context=$CTX -n $NS get gateway.gateway.networking.k8s.io
# Look for a waypoint Gateway with .spec.gatewayClassName=istio-waypoint
```

If no waypoint exists, deploy one before the chaos experiment:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: example-service-waypoint
  namespace: production
  labels:
    istio.io/waypoint-for: service
spec:
  gatewayClassName: istio-waypoint
  listeners:
    - name: mesh
      port: 15008
      protocol: HBONE
```

## What NOT to test with Istio fault

- Network partitions across zones — use the cloud provider's node pool scaling, not Istio
- Pod-level kills — use `kubectl delete pod`, not VS abort
- DNS failures — different layer; Istio doesn't see those

## Cleanup checklist

Before walking away:

```bash
kubectl --context=$CTX -n $NS get vs -l 'experiment=chaos'   # should be empty
kubectl --context=$CTX -n $NS get gateway -l 'experiment=chaos'  # should be empty
```

Tag every chaos resource with `experiment=chaos` so cleanup is greppable.
