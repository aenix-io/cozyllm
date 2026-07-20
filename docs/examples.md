# End-to-end examples

Scenarios that wire two or more cozyllm apps together. Each example assumes the catalog is already installed (see [install.md](install.md)). Replace `<ns>` with your tenant namespace throughout.

Examples built around n8n and Open WebUI (chat stack, RAG over documents, support triage, image-generation pipelines) live in the [cozyllm-nonfree](https://github.com/aenix-io/cozyllm-nonfree) catalog for licensing reasons.

## 1. AI API stack from zero

Goal: an OpenAI-compatible API running entirely inside your cluster — model serving plus a unified gateway.

```bash
# Step 1: model server (requires GPU)
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"VllmInference","metadata":{"name":"qwen"},"spec":{"model":"Qwen/Qwen2.5-7B-Instruct","gpuCount":1,"quantization":"fp16","maxContextLength":8192}}' | kubectl -n <ns> apply -f -

# Step 2: wait for the model to download and load (~5-15 min)
kubectl -n <ns> logs -l cozyllm.io/model=true -f
# Look for: "Application startup complete."

# Step 3: gateway in front of the model
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"Litellm","metadata":{"name":"gateway"},"spec":{"masterKey":"sk-master-CHANGEME","postgres":{"enabled":true,"replicas":1,"size":"5Gi","user":"litellm","name":"litellm"},"models":[{"name":"qwen-7b","url":"http://vllm-inference-qwen.<ns>.svc.cluster.local:8000/v1"}]}}' | kubectl -n <ns> apply -f -

# Step 4: test a chat completion through the gateway
kubectl -n <ns> port-forward svc/litellm-gateway 4000:4000 &
curl -sS http://localhost:4000/v1/chat/completions \
  -H 'Authorization: Bearer sk-master-CHANGEME' \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen-7b","messages":[{"role":"user","content":"hi"}]}'
```

Any OpenAI-compatible client can now sit on top of the gateway — application code, Langflow, JupyterHub notebooks, or a chat UI such as Open WebUI from the [non-free catalog](https://github.com/aenix-io/cozyllm-nonfree).

## 2. Multi-user ML notebooks

Goal: data-science team shares one JupyterHub, each user's notebooks hit the same LiteLLM gateway.

Prerequisite: example 1 (LiteLLM running).

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"JupyterHub","metadata":{"name":"team"},"spec":{"database":{"size":"5Gi","replicas":1,"user":"jupyterhub","name":"jupyterhub"}}}' | kubectl -n <ns> apply -f -
```

Bake the LLM connection into every spawned notebook by patching the inner HelmRelease values:

```bash
kubectl -n <ns> patch helmrelease jupyterhub-team-app --type merge -p '{"spec":{"values":{"singleuser":{"extraEnv":{"OPENAI_API_KEY":"sk-master-CHANGEME","OPENAI_BASE_URL":"http://litellm-gateway.<ns>.svc.cluster.local:4000/v1"}}}}}'
```

Users can now run `from openai import OpenAI; OpenAI().chat.completions.create(model="qwen-7b", messages=[...])` without any per-user config.

## 3. Visual LLM pipelines as APIs

Goal: business team designs a flow in Langflow → exports it as an HTTP endpoint → backend developers call it from production code.

Prerequisite: example 1.

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"Langflow","metadata":{"name":"flows"},"spec":{"database":{"size":"5Gi","replicas":1,"user":"langflow","name":"langflow"}}}' | kubectl -n <ns> apply -f -

kubectl -n <ns> port-forward svc/langflow-flows-app 7860:80
```

In Langflow UI at `http://localhost:7860`:

1. Build a flow (e.g. ChatInput → Prompt template → OpenAI → ChatOutput)
2. **Share → API Access** → copy the curl example
3. Hand the endpoint to backend devs — they call it without knowing the flow internals
4. When the team iterates on the flow, downstream code keeps working (same endpoint, evolved logic inside)
