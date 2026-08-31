# lakehouse

The storage-and-catalog foundation for the data stack: a Cozystack [`Bucket`](https://cozystack.io/docs/) for table data, an [Apache Iceberg](https://iceberg.apache.org) catalog in front of it, and the catalog's own managed Postgres.

Order this first. Every engine that reads or writes tables — `Trino`, `SparkCluster`, `MLflow` — points at a `Lakehouse` rather than provisioning storage of its own, because the data outlives all of them and several must see the same tables.

## Why a separate object

The catalog rule elsewhere in this repository is that dependencies come up behind the app that needs them, unnamed. `JupyterHub` does that with its Postgres.

That does not work here. If `Trino` privately created a bucket and a catalog, deleting Trino would delete the tables, and adding `SparkCluster` next to it would produce a second, disjoint lakehouse. So the lakehouse is a first-class object with its own lifecycle, and the truly disposable pieces — the catalog's Postgres — stay hidden inside it.

## Choosing a catalog

`Nessie` and `HiveMetastore` answer the same question and only one is deployed.

**Nessie** versions the catalog itself: branches, commits and merges over the state of every table at once. That is how a twenty-table nightly load becomes atomic in a world with no cross-table transactions — write on a branch, run the checks, merge in one step, and analysts never see a half-loaded warehouse. Pick this unless something forces the other.

**HiveMetastore** speaks the Hadoop-era Thrift protocol. Pick it when an existing tool understands nothing else.

## Iceberg maintenance

A classic MPP database reclaimed space and tidied storage inside `VACUUM`. Iceberg has no such thing, and two different jobs are needed — they are not the same job, and only one of them can live here.

**Unreferenced-file GC** is a catalog-side operation: walk the live references, mark the data files still reachable, sweep the rest. `nessie-gc` does this, and the CronJob in this chart runs it. It ships **disabled**: the invocation has not been validated against a running catalog, and a job whose purpose is deleting data files is the wrong place to guess at flags. Verify it, then turn it on.

**Compaction** — rewriting thousands of small Parquet files into fewer large ones — cannot live here at all. The catalog stores pointers and never touches data files; only an engine can rewrite them, through Spark's `rewrite_data_files` procedure. So compaction belongs with `SparkCluster`, and a lakehouse with no engine attached has no way to compact. That is a real gap rather than an oversight: frequent small writes will slow queries down over time, and the fix is an engine, not a setting.

## Parameters

### Common parameters

| Name           | Description                                                                                                                                                                                                                                          | Type     | Value |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| `host`         | Hostname for external access to the catalog API via Ingress. Leave empty to keep the catalog reachable only inside the cluster, which is the usual choice: engines connect over cluster DNS and nothing outside needs to speak the catalog protocol. | `string` | `""`  |
| `storageClass` | StorageClass for the catalog's Postgres PVCs. Leave empty to use the cluster default.                                                                                                                                                                | `string` | `""`  |


### Catalog

| Name      | Description                                                                                                                                                                                                         | Type     | Value    |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | -------- |
| `catalog` | Catalog implementation. Hive Metastore is deliberately absent: it has no maintained upstream Helm chart, so supporting it means owning a Deployment, and that is deferred until a consumer needs the Hive protocol. | `string` | `Nessie` |


### Storage

| Name                   | Description                                                                                  | Type     | Value  |
| ---------------------- | -------------------------------------------------------------------------------------------- | -------- | ------ |
| `storage`              | Object storage for table data.                                                               | `object` | `{}`   |
| `storage.storagePool`  | Selects a specific BucketClass by storage pool name. Leave empty for the default.            | `string` | `""`   |
| `storage.readOnlyUser` | Also issue a read-only credential alongside the read-write one, for engines that only query. | `bool`   | `true` |


### Database

| Name                | Description                                                                               | Type       | Value  |
| ------------------- | ----------------------------------------------------------------------------------------- | ---------- | ------ |
| `database`          | PostgreSQL configuration for the catalog.                                                 | `object`   | `{}`   |
| `database.size`     | Persistent Volume size for catalog metadata.                                              | `quantity` | `20Gi` |
| `database.replicas` | Number of database instances.                                                             | `int`      | `2`    |
| `database.password` | Optional explicit password. When empty, one is generated and preserved across reconciles. | `string`   | `""`   |


### Resources

| Name               | Description                                                                                                                                                                                                                                                                                                                                                                                      | Type       | Value      |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------- | ---------- |
| `resources`        | Explicit resources, overriding the preset.                                                                                                                                                                                                                                                                                                                                                       | `object`   | `{}`       |
| `resources.cpu`    | CPU available to the catalog pod.                                                                                                                                                                                                                                                                                                                                                                | `quantity` | `""`       |
| `resources.memory` | Memory available to the catalog pod.                                                                                                                                                                                                                                                                                                                                                             | `quantity` | `""`       |
| `resourcesPreset`  | Default sizing preset. Requests are derived from these limits through the platform's allocation ratios (cpu-allocation-ratio and friends from the cozystack config), so a preset states what the pod may use, not what it reserves. The catalog is a thin service over a database and is not where analytics load lands, so a small preset is right; the database behind it is sized separately. | `string`   | `t1.small` |
| `replicaCount`     | Number of catalog replicas. The service is stateless — all state is in Postgres — so this scales freely.                                                                                                                                                                                                                                                                                     | `int`      | `2`        |


### Maintenance

| Name                             | Description                                                                                                                                                         | Type     | Value       |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----------- |
| `maintenance`                    | Unreferenced-file garbage collection.                                                                                                                               | `object` | `{}`        |
| `maintenance.enabled`            | Run the GC CronJob. Off by default: the invocation has not been validated against a running catalog, and a job that deletes data files is the wrong place to guess. | `bool`   | `false`     |
| `maintenance.schedule`           | Cron schedule for the GC run.                                                                                                                                       | `string` | `0 3 * * *` |
| `maintenance.retainSnapshotDays` | Age below which content stays live. Data files unreferenced for longer become collectable, and time travel further back than this stops working.                    | `int`    | `7`         |

