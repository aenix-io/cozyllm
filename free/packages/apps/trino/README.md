# trino

Distributed SQL over the lakehouse. [Trino](https://trino.io) parses a query, plans it, and hands the work to workers that execute it in parallel — the same shape as an MPP database's coordinator and segments, except the storage is not attached to the compute.

## What it is for

Two things, and the second one is why this usually arrives first during a migration.

**Querying the lakehouse.** Point it at a `Lakehouse` and its Iceberg tables become ordinary SQL tables.

**Federation.** Trino can query several systems in one statement. During a move off an existing warehouse that is not a convenience feature, it is the migration strategy: a new Iceberg table can be joined against the system still holding the rest of the data, so the cutover happens table by table instead of all at once.

```yaml
additionalCatalogs:
  - name: legacy
    connector: postgresql
    properties:
      connection-url: jdbc:postgresql://old-warehouse:5432/analytics
      connection-user: readonly
```

## Two things that surprise people

**A query that does not fit in memory fails.** Trino computes in RAM and does not spill to disk by default, so an undersized worker preset shows up as failed queries rather than slow ones. Memory is the resource to size on; the chart derives the JVM heap from the pod limit through the upstream chart's `maxHeapPercent`, so raising the preset raises the heap with it.

**Removing a worker kills the queries running on it.** Workers hold no data and can be added freely, but they are not disposable mid-flight. Do not attach this to an HPA without a graceful-shutdown story.

## Relationship to the lakehouse

`lakehouseRef` is required and has no default. Guessing which lakehouse an engine should read is how a cluster ends up with two disjoint warehouses, so an unset value fails at render time.

Several Trino releases against one `Lakehouse` is a normal shape — one sized for interactive analysts, another for scheduled reports — and it is the reason the lakehouse is a first-class object rather than something this chart provisions privately.

Credentials for the lakehouse bucket are consumed by reference, so a rotation on the `Lakehouse` side reaches the engine without touching this release.

## Parameters

### Common parameters

| Name           | Description                                                                                                                                                                                                                                  | Type     | Value |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| `host`         | Hostname for external access to the Trino UI and JDBC endpoint via Ingress. Leave empty to keep it reachable only inside the cluster.                                                                                                        | `string` | `""`  |
| `lakehouseRef` | Name of the `Lakehouse` in this namespace whose catalog and bucket this engine reads. This is a reference rather than a private dependency on purpose: the tables outlive the engine, and several engines are expected to see the same ones. | `string` | `""`  |


### Coordinator

| Name                           | Description                                | Type       | Value       |
| ------------------------------ | ------------------------------------------ | ---------- | ----------- |
| `coordinator`                  | Query coordinator.                         | `object`   | `{}`        |
| `coordinator.resourcesPreset`  | Sizing preset for the coordinator.         | `string`   | `u1.medium` |
| `coordinator.resources`        | Explicit resources, overriding the preset. | `object`   | `{}`        |
| `coordinator.resources.cpu`    | CPU available to the pod.                  | `quantity` | `""`        |
| `coordinator.resources.memory` | Memory available to the pod.               | `quantity` | `""`        |


### Workers

| Name                       | Description                                                                                                                                                                                                                        | Type       | Value      |
| -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ---------- |
| `workers`                  | Query execution workers.                                                                                                                                                                                                           | `object`   | `{}`       |
| `workers.replicas`         | Number of workers.                                                                                                                                                                                                                 | `int`      | `2`        |
| `workers.resourcesPreset`  | Sizing preset for each worker. Memory is the resource that matters: Trino computes in RAM and a query that does not fit **fails** rather than spilling to disk, so an undersized preset shows up as failed queries, not slow ones. | `string`   | `m1.large` |
| `workers.resources`        | Explicit resources, overriding the preset.                                                                                                                                                                                         | `object`   | `{}`       |
| `workers.resources.cpu`    | CPU available to the pod.                                                                                                                                                                                                          | `quantity` | `""`       |
| `workers.resources.memory` | Memory available to the pod.                                                                                                                                                                                                       | `quantity` | `""`       |


### Federation

| Name                               | Description                                                                | Type                | Value |
| ---------------------------------- | -------------------------------------------------------------------------- | ------------------- | ----- |
| `additionalCatalogs`               | Extra catalogs for federated queries.                                      | `[]object`          | `[]`  |
| `additionalCatalogs[i].name`       | Catalog name as it appears in SQL (`SELECT ... FROM <name>.schema.table`). | `string`            | `""`  |
| `additionalCatalogs[i].connector`  | Trino connector to use, for example `postgresql`, `mysql`, `kafka`.        | `string`            | `""`  |
| `additionalCatalogs[i].properties` | Connector properties, passed through verbatim.                             | `map[string]string` | `{}`  |

