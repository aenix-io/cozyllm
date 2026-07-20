# litellm

LLM API gateway in front of one or more model backends (vLLM, public OpenAI, Anthropic, etc.). Provides unified `/v1/chat/completions`, virtual API keys, per-team quotas, usage logging. Backing service: managed Postgres (Pattern C).

## Deploy

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"Litellm","metadata":{"name":"gateway"},"spec":{"masterKey":"sk-master-CHANGEME","postgres":{"enabled":true,"replicas":1,"size":"5Gi","user":"litellm","name":"litellm"},"models":[{"name":"qwen-7b","url":"http://vllm-inference-qwen.<ns>.svc.cluster.local:8000/v1"}]}}' | kubectl -n <ns> apply -f -
```

The `models` array registers backends. Each entry maps a user-facing `name` (what clients pass in the `model` field) to a backend `url`. Add `apiKey` per model if the backend is protected.

## Spec reference

| Field | Notes |
| --- | --- |
| `masterKey` | Admin bearer key. Required. Treat as a Secret. |
| `models[]` | Array of `{name, url, apiKey?}` registering each backend |
| `postgres.enabled` | Required for credentials and budgets to persist |
| `postgres.{size,replicas,user,name,storageClass}` | Standard Pattern C Postgres |
| `host` | Hostname for external Ingress. Every request requires the master key, so the gateway is never unauthenticated. Leave empty for cluster-internal only |
| `replicaCount` | LiteLLM is stateless — safe to scale |

Full parameter list with defaults: [`values.schema.json`](../../packages/apps/litellm/values.schema.json).

## Wait for ready

Postgres bootstrap takes ~3–5 minutes:

```bash
kubectl -n <ns> get helmreleases | grep litellm
```

Both `litellm-gateway` (outer) and `postgres-litellm-gateway-db` (sibling Postgres) should reach `READY=True`.

## Use

In-cluster URL: `http://litellm-<release>.<ns>.svc.cluster.local:4000/v1`

```bash
curl http://litellm-gateway.<ns>:4000/v1/chat/completions \
  -H 'Authorization: Bearer sk-master-CHANGEME' \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen-7b","messages":[{"role":"user","content":"hi"}]}'
```

This URL is the value you set as `OPENAI_BASE_URL` in every downstream client. The master key is the bearer token, or you can mint virtual keys via the LiteLLM admin API / UI for finer-grained quotas.

## Add a model after deploy

Patch the CR's `models` array. Cozystack reconciles the change and pushes new config into LiteLLM:

```bash
kubectl -n <ns> patch litellm gateway --type merge \
  -p '{"spec":{"models":[{"name":"qwen-7b","url":"http://vllm-inference-qwen.<ns>:8000/v1"},{"name":"gpt-4o","url":"https://api.openai.com/v1","apiKey":"sk-proj-..."}]}}'
```

## Virtual API keys

LiteLLM stores per-key usage and budgets in Postgres. Generate via the master key:

```bash
curl http://litellm-gateway.<ns>:4000/key/generate \
  -H 'Authorization: Bearer sk-master-CHANGEME' \
  -H 'Content-Type: application/json' \
  -d '{"models":["qwen-7b"],"max_budget":10.0,"duration":"30d"}'
```

The response contains a `key` you hand out to a team or user. Their usage is tracked separately from others.

## Dashboard UI

LiteLLM v1.50+ ships a built-in admin UI for keys, teams, and usage. Port-forward to access:

```bash
kubectl -n <ns> port-forward svc/litellm-gateway 4000:4000
# Open http://localhost:4000/ui
```
