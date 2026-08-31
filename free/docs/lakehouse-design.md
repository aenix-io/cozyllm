# Design: lakehouse and data-engineering apps

Status: draft. This document settles the decomposition before any chart is written, because the hard question here is not how to package each component but where the seams between them go.

## The ask

A prospective customer migrating off Greenplum asked for: Trino, Hive Metastore, Nessie, Airflow, Spark, GPU operator, MLflow, Coder, Dremio.

Two of those need no work. **GPU operator** already ships with Cozystack (`packages/system/gpu-operator`, plus `hami` for GPU sharing) — it is a node-level component, not a catalog app. **Qdrant**, which came up alongside, is already an `apps.cozystack.io` kind.

One should not be built. **Dremio**'s open-source repository (`dremio/dremio-oss`, Apache-2.0) has had no commit since September 2025 while the product continues commercially. Packaging it means shipping either a stagnating snapshot or someone else's commercial build. Trino covers the same ground, is Apache-2.0, and is actively developed. Recommendation: decline Dremio, offer Trino.

One is a licensing decision rather than an engineering one. **Coder** is AGPL-3.0 with an additionally-licensed `enterprise/` directory. Everything else in the list is Apache-2.0. That is a question for the project's licensing posture, not for this design; the design below assumes it is answered yes, and nothing else depends on it.

That leaves six to build: a storage-and-catalog foundation, Trino, Spark, Airflow, MLflow, Coder.

## The component nobody asked for

**Apache Iceberg** is absent from the request and is load-bearing for everything in it. Trino, Spark and the catalogs are all Iceberg clients; without a table format, S3 holds files rather than tables.

Iceberg needs no deployment — it is a specification and a set of libraries linked into the engines. It appears in this design only as the reason the catalog exists, and as the source of two maintenance jobs (snapshot expiry, small-file compaction) that have no equivalent in a classic MPP database and that someone must schedule.

## The decomposition problem

The rule this catalog follows is that a user orders an application as a first-class object and its dependencies come up behind it, unnamed and unmanaged by them. `JupyterHub` already works this way: ordering it yields a Postgres the user never asked for and cannot see as a separate thing.

That rule is easy when the dependency is private and disposable. It is harder here, because the lakehouse has a dependency that is neither: **the data itself**.

If `Trino` privately created its own bucket and its own catalog, then deleting Trino would delete the tables, and ordering Spark next to it would produce a second, disjoint lakehouse. That is plainly wrong. The data outlives every engine that reads it, and several engines must see the same tables.

So the seam goes here:

- **The lakehouse is a first-class object**, because it has a lifecycle of its own and is deliberately shared.
- **Everything that reads or writes it is a first-class object too**, each holding a reference to the lakehouse rather than a copy of it.
- **Everything else** — the Postgres behind a catalog, the Postgres behind Airflow, the bucket behind MLflow's artifacts — stays a private dependency, exactly as JupyterHub's Postgres does today.

## The objects

### `Lakehouse`

The foundation: object storage plus a catalog. Ordering it yields a `Bucket` (Cozystack's S3), a catalog service, and the catalog's private Postgres.

```yaml
apiVersion: apps.cozystack.io/v1alpha1
kind: Lakehouse
metadata:
  name: analytics
spec:
  catalog: Nessie          # Nessie | HiveMetastore
  storage:
    size: 500Gi
  database:
    size: 20Gi
    replicas: 2
```

`catalog` is a choice, not two objects. Nessie and Hive Metastore answer the same question — where a table's current metadata lives, and how two writers commit without racing. Nessie adds git-like branches over the state of the whole catalog, which is how a multi-table nightly load becomes atomic in a world where cross-table transactions do not exist. Hive Metastore adds compatibility with anything from the Hadoop era. Running both is only reasonable when each has a named consumer.

The user never sees the catalog's Postgres. They do see the `Bucket`, because they may well want to put other things in it, and because its lifecycle is the whole point.

**Status must publish the connection contract** — catalog endpoint, warehouse URI, bucket name — because every engine below binds to it.

### `Trino`

The query engine. Stateless coordinator and workers; all persistent state belongs to the `Lakehouse` it points at.

```yaml
kind: Trino
spec:
  lakehouseRef: analytics
  workers:
    replicas: 4
    resourcesPreset: u1.xlarge
  additionalCatalogs: []     # federation: Postgres, Kafka, ...
```

`lakehouseRef` is the seam. Two Trinos against one `Lakehouse` is a valid and expected shape — one for interactive analysts, one for scheduled reports, sized differently.

Two things deserve to be in the schema rather than discovered later. Trino computes in memory and a query that does not fit **fails** rather than spilling, so memory sizing is a first-class knob and not a detail. And a worker removed mid-query kills that query, so scale-down needs graceful shutdown — which means this chart should not be casually attached to an HPA.

Federation is worth exposing early: during a Greenplum migration the ability to join a new Iceberg table against the old system in one query is not a nice-to-have, it is the migration strategy.

### `SparkCluster`

Batch compute. Deploys the Spark Operator into the ComputePlane and gives the tenant a place to submit `SparkApplication` resources.

**This one is not co-locatable.** Spark runs whatever jar or Python file the user submits — arbitrary code execution is its purpose, not a side effect. It goes to the ComputePlane, always, with no toggle. The `computePlane: false` escape hatch that `JupyterHub` offers for a trusted single-tenant install is not appropriate here.

```yaml
kind: SparkCluster
spec:
  lakehouseRef: analytics
  executors:
    maxReplicas: 20
    resourcesPreset: u1.large
  shuffleStorage:
    size: 100Gi         # local disk, not the lakehouse
```

`shuffleStorage` is called out because it is the thing that surprises people: between stages Spark writes intermediate data whose volume is comparable to the input, and it wants a fast local disk. Pointing it at network storage is how Spark deployments become mysteriously slow.

### `Airflow`

Orchestration. Private Postgres, `KubernetesExecutor` (one pod per task), and — the part that decides whether the deployment is good — DAG delivery.

**Also ComputePlane-only.** A DAG is Python that Airflow executes; `PythonOperator` is an arbitrary-code primitive by design.

```yaml
kind: Airflow
spec:
  dags:
    source: git                     # git | image
    repository: https://...
    branch: main
    secretRef: dag-repo-credentials
  database:
    size: 20Gi
```

Two shapes are worth supporting and no more: `git-sync` from a repository, and DAGs baked into an image. A shared RWX volume is the third option in the wild and it is the one that produces the most support tickets; leaving it out is deliberate.

The metadata Postgres is a private dependency, but it is the component whose loss actually hurts — it holds every run's history and state — so it should get the same backup treatment the other bundled databases get.

### `MLflow`

Experiment tracking and model registry. The simplest object in this set: a stateless server, a private Postgres for metadata, and artifact storage in the `Lakehouse`'s bucket.

```yaml
kind: MLflow
spec:
  lakehouseRef: analytics    # artifacts land in its bucket
  database:
    size: 10Gi
```

MLflow does not execute user code and stays on the management cluster. One exception to note in the docs rather than to build: `mlflow models serve` deserializes a pickle, which is code execution — if that is ever wanted it is a separate, ComputePlane-placed object, not a toggle here.

It is worth stating plainly in the user-facing docs that MLflow is **not** an alternative to Airflow. They appear in the same lists constantly and answer different questions: Airflow decides when things run, MLflow records what came out.

### `Coder`

Workspaces. Private Postgres, a PVC per workspace, and — by definition — arbitrary user environments. ComputePlane-only, for the same reason as Spark and Airflow.

The knob that matters operationally is idle timeout: a hundred analysts' workspaces left running overnight is a hundred idle PVCs and their pods.

## Placement summary

| Object | Placement | Why |
| --- | --- | --- |
| `Lakehouse` | management | services plus a database, no user code |
| `Trino` | management | executes SQL, not user code |
| `MLflow` | management | records, does not run |
| `SparkCluster` | **ComputePlane, fixed** | runs submitted jars and Python |
| `Airflow` | **ComputePlane, fixed** | DAGs are executed Python |
| `Coder` | **ComputePlane, fixed** | arbitrary user environments by design |

The three fixed ones differ from the existing `computePlane: false` toggle on `JupyterHub`, `Langflow` and `ComfyUI`. That toggle exists because those apps predate the ComputePlane module and their co-located mode is what shipped. For new objects there is no such legacy, so the safe placement should be the only placement.

### There is no platform-side routing, and there will not be

An earlier revision of this document assumed a `placement` field on `ApplicationDefinition` would eventually route an app onto the ComputePlane automatically. That field has been dropped from the platform: there is exactly one ComputePlane per tenant, and nothing chooses between planes.

Two things follow, and both are structural rather than cosmetic.

**Every ComputePlane chart carries the remote-apply wiring itself.** The management-side release renders an inner Flux `HelmRelease` with `spec.kubeConfig.secretRef` pointing at the tenant's `computeplane-cluster-admin-kubeconfig`, sets `targetNamespace`/`storageNamespace`, and injects any secrets through `valuesFrom` — the shape `JupyterHub` gained in #2. This is not a values toggle; it changes how the chart is built.

Since that wiring is permanent rather than a bridge to a future platform feature, it belongs in a **shared helper template** in this repository from the start. Three charts copying it will drift.

**A missing module must fail loudly.** With no toggle and no fallback, ordering `SparkCluster`, `Airflow` or `Coder` in a tenant that has not enabled the `computeplane` module leaves the chart with no cluster to apply to. Rendering into the tenant namespace instead would silently place untrusted code exactly where this design exists to keep it out of. The charts must refuse to render, with a message naming the module to enable.

Because there is only ever one ComputePlane, no object needs a `computePlaneRef`: the Secret name is a fixed contract.

One consequence to plan for rather than discover: with Spark on the ComputePlane and the catalog on management, every Spark commit crosses a cluster boundary on a hot path. If that shows up as a problem, the answer is to place the whole data stack on the ComputePlane — not to duplicate the catalog.

## What this leaves open

**Iceberg maintenance has no owner.** Snapshot expiry and small-file compaction are Airflow's natural job, but that makes a data-plane concern depend on an orchestrator the user may not have ordered. The alternative is a maintenance CronJob owned by `Lakehouse` itself. This should be decided before the first chart, because it changes what `Lakehouse` renders.

**Cross-cluster credentials.** An engine on the ComputePlane needs the catalog endpoint and the bucket's S3 credentials. The `JupyterHub` precedent injects secrets through Flux `valuesFrom` on the management side, which works, but it has only ever been used for a single database password — not for a credential set shared by several objects.

**Sizing presets.** Trino workers and Spark executors are memory-shaped in a way the existing `resourcesPreset` ladder was not designed for. Either the ladder gains analytics-shaped entries or these charts take explicit resources.
