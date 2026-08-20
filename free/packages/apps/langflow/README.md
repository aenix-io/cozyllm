# langflow

Visual workflow builder for LLM pipelines on Cozystack, backed by a managed Postgres provisioned via the cozystack `Postgres` sibling CR.

Powered by the upstream [langflow-ide](https://github.com/langflow-ai/langflow-helm-charts) chart.

## Parameters

### Common parameters

| Name           | Description                                                                     | Type     | Value |
| -------------- | ------------------------------------------------------------------------------- | -------- | ----- |
| `host`         | Hostname for external access via Ingress. Leave empty to skip Ingress.          | `string` | `""`  |
| `storageClass` | StorageClass for the managed Postgres PVCs. Leave empty to use cluster default. | `string` | `""`  |


### Database configuration

| Name                | Description                                                                                                  | Type       | Value      |
| ------------------- | ------------------------------------------------------------------------------------------------------------ | ---------- | ---------- |
| `database`          | PostgreSQL configuration.                                                                                    | `object`   | `{}`       |
| `database.size`     | Persistent Volume size for database storage.                                                                 | `quantity` | `5Gi`      |
| `database.replicas` | Number of database instances.                                                                                | `int`      | `2`        |
| `database.user`     | Database user Langflow connects as.                                                                          | `string`   | `langflow` |
| `database.name`     | Database name Langflow stores its flows, users, and API keys in.                                             | `string`   | `langflow` |
| `database.password` | Optional explicit password. When empty, the cozystack postgres chart generates and preserves one via lookup. | `string`   | `""`       |


### Replication

| Name           | Description                                 | Type  | Value |
| -------------- | ------------------------------------------- | ----- | ----- |
| `replicaCount` | Number of Langflow backend pods. Usually 1. | `int` | `1`   |

