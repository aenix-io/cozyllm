# comfyui

Node-based UI for Stable Diffusion / image generation. Wraps `ghcr.io/ai-dock/comfyui` (CUDA, Python, ComfyUI, supervisor — all baked in). No backing services — single-pod stateful workload with a PVC for models, outputs, and custom nodes.

## Prerequisites

GPU node with NVIDIA device plugin.

## Deploy

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"ComfyUI","metadata":{"name":"design"},"spec":{"gpuEnabled":true,"gpuCount":1,"storage":{"size":"100Gi"}}}' | kubectl -n <ns> apply -f -
```

For testing without a GPU (very slow): set `"gpuEnabled":false`.

## Spec reference

| Field | Notes |
| --- | --- |
| `gpuEnabled` | `false` falls back to CPU — testing only |
| `gpuCount` | GPUs allocated to the pod |
| `storage.size` | PVC for models + outputs + custom nodes; SD checkpoints are 2–12GB each |
| `resources.{cpu,memory}` | Override container requests/limits |
| `host` | Hostname for SSO-gated external exposure. Published only when the cluster has OIDC enabled; leave empty for cluster-internal only |

Full reference: [packages/apps/comfyui/README.md](../../packages/apps/comfyui/README.md).

## Access

ComfyUI ships no auth of its own, so it is exposed only when `host` is set and the cluster has OIDC enabled — at `https://<host>` behind an oauth2-proxy that authenticates against the platform Keycloak and admits only your tenant's groups. Without OIDC it is not published; reach it via port-forward:

```bash
kubectl -n <ns> port-forward svc/<release-name> 8188:8188
```

Open `http://localhost:8188`.

## Load models

ComfyUI expects models in `/workspace/storage/stable_diffusion/models/ckpt/` (or analogous subdirs for VAE / LoRA / embeddings). Two paths:

**From the UI** (easiest): ComfyUI Manager is bundled in the ai-dock image. **Manager → Install Models** → search → download.

**Directly into the PVC**:

```bash
POD=$(kubectl -n <ns> get pod -l app.kubernetes.io/instance=design-comfyui -o name | head -1)
kubectl -n <ns> cp ./sdxl-base.safetensors ${POD#pod/}:/workspace/storage/stable_diffusion/models/ckpt/
```

## Workflows

ComfyUI's workflows are JSON files describing the node graph. Load via **Workflow → Open** in the UI. The ai-dock image ships several example workflows; community workflows are typically downloaded from civitai.com or shared on GitHub.

## Scaling

ComfyUI is single-instance — multiple replicas each get their own PVC, which means each pod re-downloads every model. For multi-user generation pipelines, prefer one `ComfyUI` CR per user/team rather than scaling `replicaCount`.

## API mode

ComfyUI exposes a programmatic API on the same port:

```bash
# List models the instance has loaded
curl http://comfyui-design.<ns>:8188/object_info | jq '.CheckpointLoaderSimple.input.required.ckpt_name'

# Queue a workflow (post a workflow JSON)
curl -X POST http://comfyui-design.<ns>:8188/prompt \
  -H 'Content-Type: application/json' \
  -d @workflow.json
```

This is how Langflow or any workflow automation tool can drive ComfyUI as a step in an automated pipeline.
