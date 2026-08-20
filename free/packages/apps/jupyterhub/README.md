# jupyterhub

Multi-user [JupyterHub](https://jupyter.org/hub) on Cozystack, backed by a managed Postgres provisioned via the cozystack `Postgres` sibling CR.

Powered by the upstream [zero-to-jupyterhub-k8s](https://github.com/jupyterhub/zero-to-jupyterhub-k8s) chart.

## Parameters

### Common parameters

| Name           | Description                                                                     | Type     | Value |
| -------------- | ------------------------------------------------------------------------------- | -------- | ----- |
| `host`         | Hostname for external access via Ingress. Leave empty to skip Ingress.          | `string` | `""`  |
| `storageClass` | StorageClass for the managed Postgres PVCs. Leave empty to use cluster default. | `string` | `""`  |


### Database configuration

| Name                | Description                                                                                                  | Type       | Value        |
| ------------------- | ------------------------------------------------------------------------------------------------------------ | ---------- | ------------ |
| `database`          | PostgreSQL configuration.                                                                                    | `object`   | `{}`         |
| `database.size`     | Persistent Volume size for database storage.                                                                 | `quantity` | `5Gi`        |
| `database.replicas` | Number of database instances.                                                                                | `int`      | `2`          |
| `database.user`     | Database user JupyterHub connects as.                                                                        | `string`   | `jupyterhub` |
| `database.name`     | Database name JupyterHub stores its state in.                                                                | `string`   | `jupyterhub` |
| `database.password` | Optional explicit password. When empty, the cozystack postgres chart generates and preserves one via lookup. | `string`   | `""`         |


### Replication

| Name           | Description                                                                                                                                     | Type  | Value |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ----- | ----- |
| `replicaCount` | Number of JupyterHub hub pods. Usually 1 — multi-replica hub requires sticky sessions which the upstream chart does not configure by default. | `int` | `1`   |

