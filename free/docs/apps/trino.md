# trino

The SQL engine. Trino queries the tables in a `Lakehouse` and, in the same query, tables that live somewhere else entirely — a Postgres, a MySQL, a ClickHouse. It stores nothing itself.

## Deploy

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"Trino","metadata":{"name":"sql"},"spec":{"lakehouseRef":"analytics","workers":{"replicas":3}}}' | kubectl -n <ns> apply -f -
```

`lakehouseRef` is required. An engine with no warehouse to point at has nothing to do, so an unset value fails at apply time with a message rather than installing something broken.

## Query

```bash
kubectl -n <ns> port-forward svc/trino-sql 8080:8080 &
# Any JDBC client, or the trino CLI:
trino --server http://localhost:8080 --catalog lakehouse --schema default
```

```sql
CREATE SCHEMA lakehouse.sales;
CREATE TABLE lakehouse.sales.orders (id BIGINT, total DECIMAL(10,2), placed_at TIMESTAMP(6));
INSERT INTO lakehouse.sales.orders VALUES (1, 42.00, now());
SELECT * FROM lakehouse.sales.orders;
```

The `lakehouse` catalog is wired to Nessie automatically. Nessie speaks the Iceberg REST protocol, so Trino needs no Nessie-specific connector.

## Sizing

Trino is a memory engine: a join whose working set does not fit in a worker's heap fails rather than spilling gracefully. Workers default to `m1.large` for that reason, and the coordinator — which plans queries but does not execute them — stays smaller at `u1.medium`.

Heap is not set as a number. The chart hands Trino a percentage of the container limit (`maxHeapPercent: 80`), which is the upstream recommendation and keeps the JVM correct when you change the preset.

## Federating other sources

`additionalCatalogs` adds a catalog per external system, which is what makes a query like `lakehouse.sales.orders JOIN crm.public.customers` possible:

```yaml
spec:
  lakehouseRef: analytics
  additionalCatalogs:
    - name: crm
      connector: postgresql
      properties:
        connection-url: jdbc:postgresql://postgres-crm-rw:5432/crm
        connection-user: crm
        connection-password: secret
```

Credentials in `properties` land in the rendered configuration, so treat this field as you would any other place a password appears in a spec.

## Placement

Trino runs on the management cluster. It executes SQL, not user-supplied code, so it does not need the isolation that `SparkCluster`, `Airflow` and `Coder` do.
