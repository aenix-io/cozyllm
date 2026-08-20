# langflow

Visual LLM-pipeline builder. Drag components (LLM, vector store, prompt template, RAG retriever, tool, agent) onto a canvas, wire them, export the result as a REST endpoint. Wraps upstream [langflow-ide](https://github.com/langflow-ai/langflow-helm-charts). Backing service: managed Postgres (flows, users, API keys).

## Deploy

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"Langflow","metadata":{"name":"flows"},"spec":{"database":{"size":"5Gi","replicas":1,"user":"langflow","name":"langflow"}}}' | kubectl -n <ns> apply -f -
```

## Spec reference

| Field | Notes |
| --- | --- |
| `database.{size,replicas,user,name}` | Pattern C Postgres |
| `host` | Hostname for SSO-gated external exposure. Published only when the cluster has OIDC enabled; leave empty for cluster-internal only |
| `replicaCount` | Usually 1 |

Full reference: [packages/apps/langflow/README.md](../../packages/apps/langflow/README.md).

## Access

Langflow runs in anonymous mode (no auth of its own), so it is exposed only when `host` is set and the cluster has OIDC enabled — at `https://<host>` behind an oauth2-proxy that authenticates against the platform Keycloak and admits only your tenant's groups. Without OIDC it is not published; reach it via port-forward:

```bash
kubectl -n <ns> port-forward svc/langflow-service 8080:8080
```

Open `http://localhost:8080`.

## Build your first flow

1. **New Flow** → drag from the sidebar onto the canvas: **ChatInput** → **OpenAI** → **ChatOutput**
2. Click the **OpenAI** node, fill in:
   - **Base URL**: `http://litellm-gateway.<ns>.svc.cluster.local:4000/v1`
   - **API Key**: `sk-master-CHANGEME` (LiteLLM master key)
   - **Model**: `qwen-7b` (or any model name registered in LiteLLM)
3. Wire the outputs (drag from output port to input port)
4. Click **▷** (run) → chat panel opens at the bottom for testing

## Export flow as API

**Share → API Access** → Langflow shows a `curl` example:

```bash
curl http://langflow-flows-app.<ns>.svc.cluster.local:7860/api/v1/run/<flow-id> \
  -H 'Content-Type: application/json' \
  -d '{"input_value":"hi","output_type":"chat","input_type":"chat"}'
```

Use this URL from any workflow automation tool, your application code, or any HTTP client.

## RAG patterns

**New Flow → Templates** has ready-made RAG flows. The shape is:

```text
Document Loader → Text Splitter → Embedding → Vector Store (write)

User Query → Embedding → Vector Store (retrieve) → Prompt Template → OpenAI → ChatOutput
```

The **Vector Store** component supports Chroma (built-in), Qdrant (external — point at a cozystack-managed Qdrant via Pattern C), Pinecone, Weaviate.

## Tools and agents

Add a **Tool** component (HTTP request, Python code, custom function) and feed it into an **Agent**. The agent decides which tools to call based on the user query. Use this for "ChatGPT-with-tools" style flows.

## Custom Python components

**Custom Component** lets you write a Python class on the canvas — handy for one-off transformations or calling internal APIs not covered by built-in nodes.
