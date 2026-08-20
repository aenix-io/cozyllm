# open-webui

[Open WebUI](https://github.com/open-webui/open-webui) — chat interface over OpenAI-compatible APIs on Cozystack, backed by a managed Postgres provisioned via the cozystack `Postgres` sibling CR.

Designed to sit in front of the cozyllm AI cluster: point `openaiBaseApiUrl` at a `litellm` instance and Open WebUI becomes a chat UI over every model registered in that LiteLLM gateway.

The bundled Ollama subchart is disabled — model serving comes from vLLM via LiteLLM. RAG over vector storage is not wired by default; a Pattern C Qdrant integration is a natural next step (see `Vector DB notes` below).

## Vector DB notes

For document RAG, switch Open WebUI to a cozystack-managed Qdrant by adding to `extraEnvVars`:

```yaml
extraEnvVars:
  - name: VECTOR_DB
    value: qdrant
  - name: QDRANT_URI
    value: http://qdrant-<release-name>-<qdrant-cr-name>:6333
```

A Pattern C Qdrant CR can be provisioned by adding `templates/qdrant.yaml` modeled after the postgres template.

## Parameters

### Common parameters

| Name           | Description                                                                     | Type     | Value |
| -------------- | ------------------------------------------------------------------------------- | -------- | ----- |
| `host`         | Hostname for external access via Ingress. Leave empty to skip Ingress.          | `string` | `""`  |
| `storageClass` | StorageClass for the managed Postgres PVCs. Leave empty to use cluster default. | `string` | `""`  |


### Database configuration

| Name                | Description                                                                                                  | Type       | Value       |
| ------------------- | ------------------------------------------------------------------------------------------------------------ | ---------- | ----------- |
| `database`          | PostgreSQL configuration.                                                                                    | `object`   | `{}`        |
| `database.size`     | Persistent Volume size for database storage.                                                                 | `quantity` | `5Gi`       |
| `database.replicas` | Number of database instances.                                                                                | `int`      | `2`         |
| `database.user`     | Database user Open WebUI connects as.                                                                        | `string`   | `openwebui` |
| `database.name`     | Database name Open WebUI stores users, conversations, and configuration in.                                  | `string`   | `openwebui` |
| `database.password` | Optional explicit password. When empty, the cozystack postgres chart generates and preserves one via lookup. | `string`   | `""`        |


### Vector DB (optional, for RAG over documents)

| Name              | Description                                                                          | Type       | Value   |
| ----------------- | ------------------------------------------------------------------------------------ | ---------- | ------- |
| `qdrant`          | Optional Qdrant vector store.                                                        | `object`   | `{}`    |
| `qdrant.enabled`  | Provision a sibling Qdrant CR and point Open WebUI at it via VECTOR_DB + QDRANT_URI. | `bool`     | `false` |
| `qdrant.size`     | Persistent Volume size for Qdrant storage.                                           | `quantity` | `10Gi`  |
| `qdrant.replicas` | Number of Qdrant replicas.                                                           | `int`      | `1`     |


### LLM backend

| Name               | Description                                                                                                                                                                                                                                              | Type     | Value |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| `openaiBaseApiUrl` | OpenAI-compatible API endpoint. Point this at a litellm gateway (e.g. http://litellm-<name>.<namespace>.svc.cluster.local:4000/v1) to expose every model behind that gateway as a chat option in Open WebUI. Empty falls back to the public OpenAI API. | `string` | `""`  |
| `openaiApiKey`     | Bearer token for the API endpoint above. For LiteLLM, this is the master key. Stored as a Kubernetes Secret.                                                                                                                                             | `string` | `""`  |


### Replication

| Name           | Description                           | Type  | Value |
| -------------- | ------------------------------------- | ----- | ----- |
| `replicaCount` | Number of Open WebUI pods. Usually 1. | `int` | `1`   |

