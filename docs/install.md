# Install guide

This catalog plugs into an existing Cozystack cluster. It does not deploy Cozystack itself — install Cozystack first via the [`cozystack:wizard`](https://github.com/cozystack/ccp/tree/main/plugins/cozystack/skills/wizard) skill or follow [cozystack.io/docs/installation/](https://cozystack.io/docs/installation/).

## Prerequisites

- Cozystack 1.4 or newer
- FluxCD (bundled with Cozystack by default)
- `kubectl` access with cluster-admin rights, or with permissions to apply `GitRepository` + `HelmRelease` in `cozy-public` / `cozy-system`
- Outbound HTTPS access to:
  - `github.com` / `raw.githubusercontent.com` (catalog source)
  - Upstream Helm chart registries: `jupyterhub.github.io`, `langflow-ai.github.io`, `robusta-charts.storage.googleapis.com`
  - Container registries: `docker.io`, `ghcr.io`, `quay.io`

## 1. Apply the bootstrap manifest

```bash
kubectl apply -f https://raw.githubusercontent.com/aenix-io/cozyllm/main/init.yaml
```

This creates two resources in `cozy-public`:

- `GitRepository/cozyllm` — Flux source pointing at this repo's `main` branch (1-minute reconciliation interval)
- `HelmRelease/cozyllm` — installs the platform chart sourced from the GitRepository

The platform chart in turn provisions:

- 5 `ApplicationDefinition` resources (one per app)
- 2 upstream `HelmRepository` sources for the apps that wrap upstream charts
- 5 `HelmChart` sources backing each `ApplicationDefinition.spec.release.chartRef`
- 2 `Namespace`s for upstream Helm chart fetch context (`external-<app>`)

## 2. Verify install

Wait ~2 minutes. Then:

```bash
kubectl get applicationdefinitions
```

You should see five new entries (alongside Cozystack's built-ins):

```text
NAME                  AGE
comfyui               2m
jupyterhub            2m
langflow              2m
litellm               2m
vllm-inference        2m
```

If any are missing, check the platform HelmRelease:

```bash
kubectl -n cozy-system get helmrelease cozyllm
```

`READY=True` means the catalog installed cleanly. If `False`, inspect `status.conditions[*].message` for the root cause.

## 3. Pin to a release ref (recommended for production)

By default `init.yaml` tracks `branch: main`. This is fine for development but applies every commit on push. For production, pin to a semver tag or constraint — see [upgrades.md](upgrades.md).

Edit the `GitRepository` in place:

```bash
kubectl -n cozy-public patch gitrepository cozyllm --type merge \
  -p '{"spec":{"ref":{"semver":"~1.0"}}}'
```

Or to a specific tag:

```bash
kubectl -n cozy-public patch gitrepository cozyllm --type merge \
  -p '{"spec":{"ref":{"tag":"v1.0.0"}}}'
```

## 4. Use the dashboard

In the Cozystack UI navigate to **Marketplace → PaaS**. The five new apps appear with brand icons and short descriptions. Click any app to open a form generated from its `openAPISchema`.

Deploy options and use cases for each app are documented in [docs/apps/](apps/).

## Verifying a specific app

Once you deploy an app via the dashboard or `kubectl apply` of a CR, follow the reconciliation chain:

```bash
NS=<tenant-namespace>
APP=langflow
NAME=flows                 # name of your CR

# 1. The CR itself
kubectl -n $NS get $APP $NAME -o yaml

# 2. The outer HelmRelease cozystack rendered
kubectl -n $NS get helmrelease ${APP}-${NAME}

# 3. The inner HelmRelease our chart created (for upstream-wrapping apps)
kubectl -n $NS get helmrelease ${APP}-${NAME}-app

# 4. For Pattern C dependencies (Postgres / Qdrant)
kubectl -n $NS get helmrelease postgres-${APP}-${NAME}-db
kubectl -n $NS get postgres ${APP}-${NAME}-db

# 5. Pods
kubectl -n $NS get pods -l app.kubernetes.io/instance=${APP}-${NAME}-app
```

All HelmReleases should reach `READY=True`. Pod readiness is app-specific (some apps download multi-GB models on first start).

## Troubleshooting

### ApplicationDefinitions don't appear

Inspect the platform release:

```bash
kubectl -n cozy-system describe helmrelease cozyllm
```

Common causes:

- GitRepository clone failed — check Flux logs in `flux-system` and verify the repo URL is reachable from the cluster
- HelmChart can't fetch — usually a typo in `chart` or missing `HelmRepository`
- Network policy blocking outbound — Cozystack ships restrictive NetworkPolicies by default; ensure flux-source-controller can reach external HTTPS

### App pod stays Pending

```bash
kubectl -n <ns> describe pod -l app.kubernetes.io/instance=<app>-<name>-app | tail -30
```

Most common: image pull, GPU resource shortage, PVC binding to a storage class that doesn't exist, or NodeAffinity mismatch.

### App pod CrashLoopBackOff

```bash
kubectl -n <ns> logs -l app.kubernetes.io/instance=<app>-<name>-app --tail=100
```

For Postgres-backed apps, ensure the sibling Postgres CR reconciled successfully *before* the app pod started. If not, delete the app's pod — once Postgres is `READY=True`, the pod will pick up credentials on restart.

### "either chart or chartRef must be set"

If you see this error on a HelmRelease, it most likely means you are looking at an older version of the catalog (pre-`fa7976d`) where the inner HelmRelease collided with the outer cozystack-generated one. Bump your `ref` to anything newer than that commit.

### Reconcile not picking up new commits

Force a sync:

```bash
kubectl -n cozy-public annotate gitrepository cozyllm \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

## Uninstall

Removing the catalog:

```bash
kubectl -n cozy-system delete helmrelease cozyllm
kubectl -n cozy-public delete gitrepository cozyllm
```

This removes the platform registration. **Existing app instances continue to run** — delete each CR first if you want to clean them up too:

```bash
kubectl get vllminference,litellm,comfyui,jupyterhub,langflow -A
# Then delete the ones you no longer need.
```

Postgres CRs created as Pattern C dependencies are not automatically garbage-collected; remove them after their consumer app:

```bash
kubectl get postgres -A | grep -E 'litellm|jupyterhub|langflow'
```
