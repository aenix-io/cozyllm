# lakehouse

The storage layer everything else in this group points at. A `Lakehouse` is object storage plus the catalog that turns the files in it into tables, and it is a first-class object because the data outlives the engines that read it: you can delete Trino and Spark and recreate them next week against the same tables.

## Deploy

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"Lakehouse","metadata":{"name":"analytics"},"spec":{"catalog":"Nessie","database":{"size":"10Gi","replicas":2}}}' | kubectl -n <ns> apply -f -
```

That single object provisions three things: a `Bucket` holding the Parquet files, a Nessie catalog serving the Iceberg REST protocol, and the Postgres the catalog keeps its state in. You address only the `Lakehouse`.

## What is stored where

Table data — the actual rows, as Parquet — lives in the bucket. The catalog stores no data at all: for each table it records which metadata file is current, and it serialises the commits that move that pointer. This is what makes a write atomic. An engine writes new Parquet files, then asks the catalog to swap the pointer, and readers see either the old snapshot or the new one and never a half-written table.

The consequence worth internalising: **losing the catalog is worse than it sounds.** The bucket still holds every byte, but nothing knows which files constitute the current version of which table. That is why the catalog's Postgres defaults to two replicas and why both it and the bucket carry a keep policy — uninstalling the app does not delete either.

## Spec reference

See the [chart README](../../packages/apps/lakehouse/README.md) for the full parameter table. The fields you normally set:

| Field | Meaning |
| --- | --- |
| `catalog` | Catalog implementation. `Nessie` is the only value today. |
| `database.size` / `database.replicas` | The catalog's Postgres. Size it for metadata, not for data. |
| `storage.storagePool` | Which storage pool backs the bucket. Empty uses the default. |
| `storage.readOnlyUser` | Also issue a read-only credential, for query engines that must not write. |
| `host` | Expose the catalog's REST endpoint externally. Leave empty to keep it internal. |

## Credentials

The bucket issues one Secret per user, named `bucket-lakehouse-<name>-<user>-credentials`, with the keys `accessKey`, `secretKey`, `endpoint` and `bucketName`. Note that `endpoint` carries no scheme and `bucketName` is assigned by the storage driver rather than being the name you chose — engines read both at runtime rather than having them baked into their configuration.

```bash
kubectl -n <ns> get secret bucket-lakehouse-analytics-rw-credentials -o jsonpath='{.data.bucketName}' | base64 -d
```

## Maintenance

Iceberg accumulates two kinds of debris. Expired snapshots keep old data files referenced long after nothing reads them, and streaming or small-batch writes leave a table as thousands of tiny Parquet files that make every scan slow.

The first is the catalog's problem and this chart ships a `nessie-gc` CronJob for it, **disabled by default** because its invocation has not been verified against a real warehouse here. Enable it deliberately after checking what it would collect.

The second cannot be fixed by the catalog at all — rewriting data files requires an engine that can read and write Parquet. Compaction therefore runs from `SparkCluster`, via `CALL lakehouse.system.rewrite_data_files(...)`.

## Connect an engine

Every compute app takes a `lakehouseRef` naming this object:

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"Trino","metadata":{"name":"sql"},"spec":{"lakehouseRef":"analytics"}}' | kubectl -n <ns> apply -f -
```
