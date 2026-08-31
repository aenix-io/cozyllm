# mlflow

Experiment tracking and model registry. [MLflow](https://mlflow.org) records what a training run was given and what it produced — parameters, metrics, the resulting model file — and versions those models so a team can tell which one is in production.

## It is not an alternative to Airflow

The two appear in the same lists constantly and answer different questions. **Airflow decides when things run** and in what order. **MLflow records what came out.** A normal setup has both: Airflow schedules the training job on a timer, and the job itself logs its parameters and results to MLflow.

If what you need is a scheduler, this is the wrong object.

## What it stores where

Metadata — runs, parameters, metrics, the registry — goes to a private Postgres this chart provisions. Artifacts, which are large and binary, go to the bucket of the `Lakehouse` named in `lakehouseRef`, under an `mlflow/` prefix.

That split is why `lakehouseRef` is required rather than optional: without it there is nowhere for a trained model to land.

Losing the Postgres loses the experiment history. The artifacts in the bucket survive, but as files nobody can attribute to a run, so treat it as a database that matters rather than a cache.

## Why there is no upstream chart here

MLflow publishes no Helm chart. The ones on Artifact Hub are third-party repositories with no maintenance commitment, so this chart renders the Deployment directly against the official `ghcr.io/mlflow/mlflow` image. The server is a single process — there was little for a chart to abstract.

## Placement

The tracking server records and serves; it executes nothing a user supplied. So unlike `SparkCluster`, `Airflow` and `Coder` it stays on the management cluster.

One exception worth knowing about rather than enabling: `mlflow models serve` loads a model by deserializing a pickle, which is code execution. If model serving is ever wanted it belongs in a separate, ComputePlane-placed object — not as a flag here.

## Parameters

### Common parameters

| Name           | Description                                                                                                                                                                                                                       | Type     | Value |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| `host`         | Hostname for external access to the MLflow UI and tracking API via Ingress. Leave empty to keep it reachable only inside the cluster.                                                                                             | `string` | `""`  |
| `storageClass` | StorageClass for the managed Postgres PVCs. Leave empty to use the cluster default.                                                                                                                                               | `string` | `""`  |
| `lakehouseRef` | Name of the `Lakehouse` in this namespace whose bucket holds the run artifacts — models, plots, whatever a training run writes. Metadata lives in the private Postgres below; artifacts are large and belong in object storage. | `string` | `""`  |


### Database

| Name                | Description                                                                               | Type       | Value  |
| ------------------- | ----------------------------------------------------------------------------------------- | ---------- | ------ |
| `database`          | PostgreSQL configuration.                                                                 | `object`   | `{}`   |
| `database.size`     | Persistent Volume size for metadata.                                                      | `quantity` | `10Gi` |
| `database.replicas` | Number of database instances.                                                             | `int`      | `2`    |
| `database.password` | Optional explicit password. When empty, one is generated and preserved across reconciles. | `string`   | `""`   |


### Resources

| Name               | Description                                                                                                                                                    | Type       | Value       |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ----------- |
| `resources`        | Explicit resources, overriding the preset.                                                                                                                     | `object`   | `{}`        |
| `resources.cpu`    | CPU available to the server.                                                                                                                                   | `quantity` | `""`        |
| `resources.memory` | Memory available to the server.                                                                                                                                | `quantity` | `""`        |
| `resourcesPreset`  | Default sizing preset. The tracking server records runs rather than executing them, so it stays small no matter how large the training jobs writing to it are. | `string`   | `t1.medium` |
| `replicaCount`     | Number of tracking-server replicas. Stateless — all state is in Postgres and the bucket — so this scales freely.                                           | `int`      | `2`         |

