# Running code-executing apps on a ComputePlane

Several cozyllm apps run arbitrary user code as a core feature: JupyterHub notebooks, Langflow custom components, ComfyUI custom nodes (and, in cozyllm-nonfree, n8n code nodes and Open WebUI tools/pipelines). Container isolation is not a multi-tenancy boundary for such workloads — a container escape would land user code on the shared management cluster. Cozystack's answer is the **ComputePlane**: a hidden, Cozystack-managed Kubernetes cluster (Kamaji control plane + KubeVirt-VM workers) provisioned per tenant, where untrusted workloads run without any credentials for — or network route back to — the management kube-apiserver. See the upstream design in [cozystack/community design-proposals/compute-plane](https://github.com/cozystack/community/tree/main/design-proposals/compute-plane).

Inference-only apps (vLLM, LiteLLM) accept prompts and return tokens; they do not execute user code and stay co-located on the management cluster.

## Enabling

ComputePlane placement is opt-in per app instance: set `computePlane: true` in the app values (default `false`). With the toggle off, every chart renders exactly as before, fully co-located in the tenant namespace.

Prerequisites:

- A Cozystack release that ships the `computeplane` tenant module (the module wraps the managed `kubernetes` app as `placement: ComputePlane` infrastructure).
- The tenant must have the `etcd` module enabled (the managed Kubernetes cluster the module provisions is etcd-backed) and the `computeplane` module turned on, which creates the `computeplane-cluster` HelmRelease in the tenant namespace.

## The consumer pattern

The app release itself always stays on the management cluster; only the untrusted workload moves. With `computePlane: true` the management-side chart renders an inner Flux `HelmRelease` that carries:

```yaml
spec:
  kubeConfig:
    secretRef:
      name: computeplane-cluster-admin-kubeconfig
      key: super-admin.svc
  targetNamespace: <tenant namespace>
  storageNamespace: <tenant namespace>
  install:
    createNamespace: true
```

The management helm-controller resolves the chart and remote-applies the rendered manifests into the ComputePlane through that kubeconfig — no Flux (and no cozystack machinery) needs to run inside the ComputePlane. `computeplane-cluster-admin-kubeconfig` is the admin kubeconfig Kamaji writes for the module's `computeplane-cluster` HelmRelease; the name is derived from that object name and is the contract every consumer references. The tenant never sees this Secret.

`targetNamespace` plus `install.createNamespace` mirror the tenant namespace onto the ComputePlane (it does not exist there beforehand).

## Secrets and private dependencies

The workload pods on the ComputePlane cannot mount or reference Secrets that live on the management cluster, so the charts avoid cross-cluster `secretKeyRef`s in two ways:

- **Flux `valuesFrom`** — the management helm-controller reads a management-side Secret and injects the value into the chart values before applying remotely (used for the JupyterHub DB password and the gatekeeper OIDC client/cookie secrets).
- **Generate-and-pass-as-value** — the chart generates a credential once (lookup existing Secret → reuse, else random), stores it management-side, and writes the same value into the workload values (used for the Langflow/n8n/Open WebUI DB passwords and app secret keys).

Stateful private dependencies stay on the management cluster: in ComputePlane mode the bundled Postgres is a raw CNPG `Cluster` rendered by the app chart (hidden from the user, not a first-class app), and the workload reaches it by DNS — `postgres-<release>-db-rw` resolves from the ComputePlane pods through their `*.svc` search domain back to the tenant namespace on management.

## Exposure

The workload's Ingress (and the OIDC gatekeeper's, for gated apps) lives inside the ComputePlane on its pinned `ingress-nginx` addon (`className: nginx`), with TLS from the ComputePlane's pinned cert-manager. The app host is brought back to the tenant's normal entry point by a per-app management Ingress (`<release>-computeplane`) that proxies with `ssl-passthrough` to the `computeplane-cluster-ingress-nginx` Service — the Proxied NodePort Service the module creates in the tenant namespace, selecting the ComputePlane's ingress nodes. No management LoadBalancer is allocated and no per-host wiring is needed on the module side.

For gated apps (JupyterHub, Langflow, ComfyUI, Open WebUI) the oauth2-proxy gatekeeper itself runs inside the ComputePlane, deployed as another remote-applied HelmRelease; only the `KeycloakClient` registration and the generated client/cookie Secrets stay on management.
