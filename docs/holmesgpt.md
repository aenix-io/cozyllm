# HolmesGPT (admin-only)

HolmesGPT is an AI SRE agent that investigates Kubernetes issues by reading cluster state and asking an LLM. Unlike the apps in the tenant marketplace, it is **not** tenant-deployable: its upstream chart grants cluster-wide read RBAC (pods, pod logs, configmaps, services across every namespace), which is appropriate for a single operator-owned instance but would let any tenant read every other tenant's workloads. It is therefore installed once, by the cluster admin, as a platform component — never registered as an `ApplicationDefinition`, so it cannot appear in the tenant dashboard.

## Enable it

Set the values on the cozyllm platform `HelmRelease` (the one created by `init.yaml` in `cozy-system`):

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cozyllm
  namespace: cozy-system
spec:
  values:
    holmesgpt:
      enabled: true
      model: "openai/qwen-7b"
      openaiBaseUrl: "http://litellm-<release>.<namespace>.svc.cluster.local:4000/v1"
      openaiApiKey: "<litellm-master-key>"
```

| Field | Notes |
| --- | --- |
| `enabled` | Install the cluster-wide HolmesGPT instance. Default `false` |
| `model` | LiteLLM-format model id (e.g. `openai/qwen-7b`, `anthropic/claude-3-5-sonnet`) |
| `openaiBaseUrl` | OpenAI-compatible endpoint. Point at an in-cluster LiteLLM gateway to keep SRE LLM calls inside the cluster. Empty falls back to the public OpenAI API |
| `openaiApiKey` | Bearer token for the endpoint (for LiteLLM, the master key). Stored as a Secret |
| `replicas` | Number of HolmesGPT pods. Default `1` |

Flux installs HolmesGPT into the `cozy-holmesgpt` namespace within ~2 minutes.

## Use it

```bash
kubectl -n cozy-holmesgpt get pod -l app.kubernetes.io/name=holmes
kubectl -n cozy-holmesgpt port-forward svc/holmesgpt-holmes 8080:80
```

Then POST investigations to `http://localhost:8080/api/investigate`, or ask ad-hoc questions via `/api/chat`. Point any OpenAI-compatible chat front-end at the same endpoint to drive cluster diagnostics conversationally.

## Why not the dashboard

A tenant deploying HolmesGPT would obtain a ServiceAccount bound to a cluster-wide `ClusterRole` and could read every other tenant's pod logs. The platform reconciles tenant releases with cluster-admin privileges, so curation is the only boundary — which is exactly why HolmesGPT lives here as an opt-in platform component instead of in the marketplace.
