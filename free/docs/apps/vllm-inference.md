# vllm-inference

GPU-accelerated LLM inference server with an OpenAI-compatible HTTP API. Wraps the upstream [`vllm/vllm-openai`](https://github.com/vllm-project/vllm) container image. No backing services.

## Prerequisites

- A node with at least one NVIDIA GPU
- NVIDIA device plugin installed (Cozystack ships this on GPU-labelled nodes by default)
- HuggingFace token for gated models (Llama, Mistral, Phi-4)

## Deploy

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"VllmInference","metadata":{"name":"qwen"},"spec":{"model":"Qwen/Qwen2.5-7B-Instruct","gpuCount":1,"quantization":"fp16","maxContextLength":8192}}' | kubectl -n <ns> apply -f -
```

For gated models add `"huggingfaceToken":"hf_..."`. To protect the endpoint with bearer auth, add `"apiKey":"sk-..."`.

## Spec reference

| Field | Notes |
| --- | --- |
| `model` | One of seven presets: Llama 3.1 8B/70B, Mistral 7B, Qwen 2.5 7B/72B, DeepSeek-R1 8B, Phi-4 |
| `gpuCount` | 1, 2, 4, 8 (tensor parallelism) |
| `quantization` | `fp16` (best quality), `fp8`, `awq`, `gptq` — model must be pre-quantized for awq/gptq |
| `maxContextLength` | 4K–128K tokens (KV cache scales with this) |
| `huggingfaceToken` | Required for gated models, stored as Kubernetes Secret |
| `apiKey` | Optional bearer-token auth on the endpoint |
| `storage.size` | PVC for model weights: 50Gi / 100Gi / 200Gi / 500Gi |
| `host` | Hostname for external Ingress. Requires `apiKey` to be set — the chart refuses to publish an unauthenticated endpoint. Otherwise cluster-internal only |
| `gpuEnabled` | Set `false` for CPU-only test mode (very slow) |
| `replicaCount` | Usually 1 — multi-replica needs N×GPU |

Full parameter list with defaults: [`values.schema.json`](../../packages/apps/vllm-inference/values.schema.json).

## Wait for ready

First start downloads model weights from HuggingFace (5–15 minutes depending on model size). The `/health` endpoint returns 503 until the model loads — that's intentional, so no readinessProbe is configured.

```bash
kubectl -n <ns> get pods -l cozyllm.io/model=true
kubectl -n <ns> logs -l cozyllm.io/model=true -f
```

Wait for `INFO uvicorn.error: Application startup complete.` — the API is then serving requests.

## Use

In-cluster URL: `http://vllm-inference-<release>.<ns>.svc.cluster.local:8000/v1`

Send a chat request from a debug pod:

```bash
kubectl run curl --rm -it --image=curlimages/curl -- \
  curl -sS http://vllm-inference-qwen.<ns>:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen2.5-7B-Instruct","messages":[{"role":"user","content":"hi"}]}'
```

External access: set `spec.host` together with `spec.apiKey` and the chart provisions a TLS Ingress. Setting `host` without `apiKey` is rejected — the endpoint must not be exposed without a bearer token. Put a LiteLLM gateway in front (see below) for richer auth.

## Recommended: register through LiteLLM

Don't connect downstream apps (Langflow, chat UIs, workflow automation tools) directly to vLLM. Instead deploy a `LiteLLM` instance and register this vLLM as a backend — you get unified auth, virtual API keys, per-team budgets, and the ability to switch models server-side without changing every client. See [litellm.md](litellm.md).

## Scaling

Multiple replicas do not share GPU state — each replica requires its own GPU(s):

- 1 replica × 1 GPU = 1 GPU
- 2 replicas × 1 GPU = 2 GPUs

For multiple models, prefer one `VllmInference` CR per model rather than one CR with multiple replicas.
