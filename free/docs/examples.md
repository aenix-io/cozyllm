# End-to-end examples

Scenarios that wire two or more cozyllm apps together. Each example assumes the catalog is already installed (see [install.md](install.md)). Replace `<ns>` with your tenant namespace throughout.

Examples built around n8n and Open WebUI (chat stack, RAG over documents, support triage, image-generation pipelines) live in the [`contrib/`](../../contrib/) catalog for licensing reasons.

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

Any OpenAI-compatible client can now sit on top of the gateway — application code, Langflow, JupyterHub notebooks, or a chat UI such as Open WebUI from the [contrib catalog](../../contrib/).

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

## 4. Lakehouse from zero

Goal: a warehouse whose tables outlive the engines that read them, with SQL over it, batch jobs that maintain it, and a scheduler driving both.

Order matters here only in one place: the `Lakehouse` must exist before anything that names it, because the compute apps refuse to install without a warehouse to point at.

```bash
# Step 1: storage and catalog. This one object provisions the bucket, the
# Nessie catalog and the Postgres behind it.
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"Lakehouse","metadata":{"name":"analytics"},"spec":{"catalog":"Nessie","database":{"size":"10Gi","replicas":2}}}' | kubectl -n <ns> apply -f -

# Step 2: wait for the catalog to come up
kubectl -n <ns> wait --for=condition=Ready lakehouse/analytics --timeout=10m

# Step 3: SQL over it
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"Trino","metadata":{"name":"sql"},"spec":{"lakehouseRef":"analytics","workers":{"replicas":3}}}' | kubectl -n <ns> apply -f -

# Step 4: create a table and put a row in it
kubectl -n <ns> port-forward svc/trino-sql 8080:8080 &
trino --server http://localhost:8080 --catalog lakehouse --execute "
  CREATE SCHEMA IF NOT EXISTS lakehouse.sales;
  CREATE TABLE lakehouse.sales.orders (id BIGINT, total DECIMAL(10,2), placed_at TIMESTAMP(6));
  INSERT INTO lakehouse.sales.orders VALUES (1, 42.00, now());
  SELECT * FROM lakehouse.sales.orders;"
```

At this point the data is in your bucket as Parquet and the catalog knows it as a table. Everything from here is optional and additive.

### Adding compute and scheduling

`SparkCluster`, `Airflow` and `Coder` run on the tenant's own Kubernetes cluster rather than the management one, because each of them runs code you supply. Enable the module once:

```bash
kubectl -n <root-ns> patch tenant <name> --type merge -p '{"spec":{"computeplane":true}}'
kubectl -n <root-ns> wait --for=condition=Ready computeplane/<name> --timeout=30m
```

```bash
# Batch compute, which is also what maintains the warehouse
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"SparkCluster","metadata":{"name":"batch"},"spec":{"lakehouseRef":"analytics"}}' | kubectl -n <ns> apply -f -

# The scheduler that drives it
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"Airflow","metadata":{"name":"pipelines"},"spec":{"dags":{"repo":"https://github.com/acme/dags.git","branch":"main"},"host":"airflow.example.com"}}' | kubectl -n <ns> apply -f -
```

Ordering an app without the module is not a silent failure: the apply is rejected with a message naming what to enable.

### Keeping it fast

Iceberg tables degrade in a specific, predictable way — a stream of small writes leaves thousands of tiny Parquet files, and every scan pays for it. Fixing that means physically rewriting the files, which only an engine can do, so it belongs in a scheduled Spark job rather than anywhere near the catalog:

```sql
CALL lakehouse.system.rewrite_data_files(table => 'sales.orders');
CALL lakehouse.system.expire_snapshots(table => 'sales.orders', older_than => TIMESTAMP '2026-01-01 00:00:00');
```

### Tracking models trained on it

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"MLflow","metadata":{"name":"tracking"},"spec":{"lakehouseRef":"analytics"}}' | kubectl -n <ns> apply -f -
```

MLflow keeps run metadata in its own Postgres and writes artifacts into the same bucket under an `mlflow/` prefix. It is not an alternative to Airflow — Airflow decides when the training job runs, MLflow records what it produced.

