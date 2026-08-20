# End-to-end examples

Scenarios built around the apps in this contrib catalog (n8n, Open WebUI), wired together with apps from the [free](../../free/) catalog. Each example assumes both catalogs are installed (apply each section's `init.yaml`, see the [free catalog's install guide](../../free/docs/install.md)) and that you already have a LiteLLM gateway running — see the ["AI API stack from zero" example](../../free/docs/examples.md) there. Replace `<ns>` with your tenant namespace throughout.

## 1. Chat UI on top of the gateway

Goal: a chat interface over the in-cluster LiteLLM gateway.

```bash
# Chat UI wired to the gateway
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"OpenWebUI","metadata":{"name":"chat"},"spec":{"database":{"size":"5Gi","replicas":1,"user":"openwebui","name":"openwebui"},"openaiBaseApiUrl":"http://litellm-gateway.<ns>.svc.cluster.local:4000/v1","openaiApiKey":"sk-master-CHANGEME"}}' | kubectl -n <ns> apply -f -

# Port-forward to the chat UI
kubectl -n <ns> port-forward svc/open-webui-chat-app 3000:80
# Open http://localhost:3000 → create owner account → start chatting
```

## 2. RAG over your company documents

Goal: chat that can quote from internal PDFs and Markdown files.

```bash
# Add Qdrant to the chat stack from example 1:
kubectl -n <ns> patch openwebui chat --type merge \
  -p '{"spec":{"qdrant":{"enabled":true,"size":"10Gi","replicas":1}}}'
```

Wait for `helmrelease/qdrant-chat-vector` to reach Ready. Then in Open WebUI:

1. **Settings → Documents → +** → upload PDFs / .md files
2. The webui chunks documents, embeds via the configured embedding model, stores in Qdrant
3. Future chats retrieve relevant chunks → injected into LLM context

For programmatic indexing (e.g. nightly Confluence sync), use n8n's HTTP Request node against Open WebUI's `/api/v1/documents/upload`.

## 3. AI-powered support triage

Goal: WHMCS sends ticket-created webhook → n8n classifies → routes to Slack channels by type.

Prerequisite: a running LiteLLM gateway (see the free catalog's examples).

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"N8n","metadata":{"name":"triage"},"spec":{"database":{"size":"5Gi","replicas":1,"user":"n8n","name":"n8n"},"encryptionKey":"'$(openssl rand -hex 32)'"}}' | kubectl -n <ns> apply -f -

kubectl -n <ns> port-forward svc/n8n-triage-app 5678:80
```

In n8n at `http://localhost:5678`:

1. **New Workflow** → add **Webhook** trigger → copy the test URL
2. → **OpenAI Chat Model** node:
   - Credentials: base URL `http://litellm-gateway.<ns>:4000/v1`, master key as API key
   - Model: `qwen-7b`
   - Prompt: `"Classify this support ticket as one of: billing | technical | sales | abuse. Output only the label. Ticket: {{ $json.body.subject }} {{ $json.body.message }}"`
3. → **Switch** node, conditions on the classification output
4. Each branch → **Slack** node → respective channel
5. **Activate** workflow
6. In WHMCS: point ticket-created webhook at the n8n URL from step 1

## 4. Image generation pipeline

Goal: n8n triggers ComfyUI to generate an image, posts it back to Slack.

Prerequisite: example 3 (n8n running), plus a ComfyUI instance from the free catalog on a GPU-capable node:

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"ComfyUI","metadata":{"name":"design"},"spec":{"gpuEnabled":true,"gpuCount":1,"storage":{"size":"100Gi"}}}' | kubectl -n <ns> apply -f -
```

Load at least one Stable Diffusion checkpoint into ComfyUI (via the UI's Manager → Install Models).

In n8n:

1. Trigger (Schedule / Slack slash command / Webhook)
2. → **HTTP Request** node:
   - Method: POST
   - URL: `http://comfyui-design.<ns>:8188/prompt`
   - Body: a workflow JSON (export from ComfyUI's UI via Save (API Format))
3. Poll `/history/<prompt_id>` until the image is ready
4. Download the image from `/view?filename=...` → upload to Slack node
